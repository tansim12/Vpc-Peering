terraform {
  backend "remote" {
    organization = "Tansim"

    workspaces {
      name = "DevOps"
    }
  }

}

