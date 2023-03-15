terraform {
  cloud {
    organization = "daniela-org"

    workspaces {
      name = "vra2-private"
    }
  }
}

terraform {
  required_providers {
    vra2 = {
      source = "app.terraform.io/daniela-org/vra2"
      version = "0.7.1"
    }
  }
}

provider "vra2" { 
  # Configuration options 
}