class WelcomePage < ApplicationPage
  include Crumble::Crababel

  root_path "/"

  template do
    h1 { t.welcome }
  end
end
