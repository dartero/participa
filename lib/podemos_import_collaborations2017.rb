class PodemosImportCollaborations2017

  def self.log_to_file(filename, text)
    File.open(filename, 'a') { |f| f.write(text) }
  end

  def self.process_row(row)
    params = { document_vatid: row["DNI"].strip.upcase,
      full_name: row["Apellido 1"] ? "#{row['Nombre']} #{row['Apellido1']} #{row['Apellido2']}" : row['Nombre'],
      email: row["Email"],
      ccc_1: row["entidad"], #todas las cuentas quitamos IBAN y tratamos como ccc
      ccc_2: row["oficina"],
      ccc_3: row["cC"],
      ccc_4: row["cuenta"],
      #iban_1: row["IBAN"],
      #iban_2: row["BIC/SWIFT"],
      #payment_type: row["Método de pago"],
      amount: row["Importe mensual"].to_i * 100.0, #entero libre entre 5 y 500
      frequency: 1, #row["Frecuencia de pago"],  # 1 3 12 #siempre mensual
      created_at: DateTime.now, # Fecha automática
      row: row
    }

    self.create_collaboration(params)
  end

  def self.create_collaboration(params)
    # si el usuario tiene el mismo correo en colabora y participa...
    if User.exists?(email: params[:email])
      user = User.find_by_email params[:email]
      # ... y si tambien tiene el mismo documento, lo damos de alta
      if user.document_vatid == params[:document_vatid]
        c = Collaboration.new
        c.user = user
        c.amount = params[:amount]
        c.frequency = params[:frequency]
        c.created_at = params[:created_at]
        #case params[:payment_type]
        #when "Suscripción con Tarjeta de Crédito/Débito"
        #  c.payment_type = 1
        #when "Domiciliación en cuenta bancaria (CCC)"
          c.payment_type = 2
          c.ccc_entity = params[:ccc_1]
          c.ccc_office = params[:ccc_2]
          c.ccc_dc = params[:ccc_3]
          c.ccc_account = params[:ccc_4]
        #when "Domiciliación en cuenta extranjera (IBAN)"
        #  c.payment_type = 3
        #  c.iban_account = params[:iban_1]
        #  c.iban_bic = params[:iban_2]
        #else
        #  self.log_to_file "#{Rails.root}/log/collaboration/not_payment_type.txt", params[:row]
        #end
        if c.valid?
          c.save
          self.log_to_file "#{Rails.root}/log/collaboration/valid.txt", params[:row]
        else
          # en caso de que tenga un iban_account pero no un iban_bic ...
          if c.errors.messages[:iban_bic].first == "no puede estar en blanco"
            # ... y la cuenta bancaria sea española
            #if params[:iban_1].starts_with? "ES"
            #  # convertimos de IBAN a CCC
            #  params[:ccc_1] = params[:iban_1][4..7]
            #  params[:ccc_2] = params[:iban_1][8..11]
            #  params[:ccc_3] = params[:iban_1][12..13]
            #  params[:ccc_4] = params[:iban_1][14..23]
            #  params[:iban_1] = nil
            #  params[:payment_type] = "Domiciliación en cuenta bancaria (CCC)"
            #  self.create_collaboration(params)
            #else
              self.log_to_file "#{Rails.root}/log/collaboration/valid_not_bic.txt", "#{params[:row]}"
            end
          else
            self.log_to_file "#{Rails.root}/log/collaboration/not_valid.txt", "#{params[:row]};#{c.errors.messages.to_s}"
          end
        end
      else
        # Si el usuario Existe
          # Si tiene colaboración económica se anula esta y se envia a un fichero ANULADO POR TENER COLABORACION EN PARTICIPA.
          # Si no tiene colaboración económica vincula esta y se envía a un fichero INVITAR A QUE HAGA LA COLABORACION POR PARTICIPA.
        # si concuerda el correo pero no el documento, comprobamos si su nombre es el mismo en colabora y participa
        if user.full_name.downcase == params[:full_name].downcase
          # en ese caso lo guardamos con el documento de participa
          params[:document_vatid] = user.document_vatid
          self.create_collaboration(params)
        else
          self.log_to_file "#{Rails.root}/log/collaboration/not_document.txt", params[:row]
        end
      end
    else
      # en cambio, si no concuerda el email pero si hay alguno documento
      if User.exists?(document_vatid: params[:document_vatid])
        user = User.find_by_document_vatid params[:document_vatid]
        # comprobamos si su nombre es el mismo en colabora y participa
        if user.full_name.downcase == params[:full_name].downcase
          # en ese caso lo guardamos con el email de participa
          params[:email] = user.email
          self.create_collaboration(params)
        else
          self.log_to_file "#{Rails.root}/log/collaboration/not_email.txt", params[:row]
        end
      else
        # por ultimo, usuarios de los que no tenemos ni el email ni el documento en participa
        self.log_to_file "#{Rails.root}/log/collaboration/not_participation.txt", params[:row]
      end
    end
  end

  def self.init csv_file
    CSV.foreach(csv_file, headers: true) do |row|
      begin
        process_row row
      rescue
        self.log_to_file "#{Rails.root}/log/collaboration/exception.txt", row
      end
    end
  end

end
