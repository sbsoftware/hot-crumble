abstract class ApplicationRecord < Orma::Record
  macro inherited
    id_column id : Int64
  end
end
