# private-provider-tfc
This is a test repository to add an existing public provider to the private registry of Terraform Cloud.

The `vra` [public provider by Vmware](https://registry.terraform.io/providers/vmware/vra/latest/docs) will be added to the private registry of Terraform Cloud.

**NOTE**: The exact same steps can be followed for a Terraform Enterprise installation.

## Instructions

This repository has been created only for learning purposes and it is based on the [official documentation from HashiCorp](https://developer.hashicorp.com/terraform/cloud-docs/registry/publish-providers) and [this Github](https://github.com/slavrdorg/tfc-publish-private-provider/blob/main/README.md) step by step guide.

All the commands have been executed on a **MacOS system**. For other operating systems, please adjust accordingly where needed.

### Prerequisites

- [X] [Terraform](https://www.terraform.io/downloads)
- [X] [Terraform Cloud account](https://app.terraform.io/public/signup/account)

## How to Use this Repo

- Clone this repository:
```shell
git clone git@github.com:dlavric/private-provider-tfc.git
```

- Go to the directory where the repository is stored:
```shell
cd private-provider-tfc
```

## Steps for preparing the new provider to be uploaded to the private registry of Terraform Cloud

- Create a file `providers.tf` with the content of the provider that you want to download. In this case is going to be the [vra provider](https://registry.terraform.io/providers/vmware/vra/latest/docs):
```
terraform {
  required_providers {
    vra = {
      source = "vmware/vra"
      version = "0.7.1"
    }
  }
}

provider "vra" {
  # Configuration options
}
``` 

- Download the provider files to a directory on your local machine:
```shell
terraform providers mirror /Users/daniela/Downloads/private-provider-tfc

- Mirroring vmware/vra...
  - Selected v0.7.1 to meet constraints 0.7.1
  - Downloading package for darwin_amd64...
  - Package authenticated: signed by a HashiCorp partner
```

Observe that a new folder named `registry.terraform.io` has been created and it contains the `vra` provider.
![Vra provider files](https://github.com/dlavric/private-provider-tfc/blob/main/pictures/vra-provider-folder.png)

- Install the `jq` package:
```shell
brew install jq
```

- Install the `gnupg` package, needed for creating a gpg public key:
```shell
brew install gnupg
```

- Create a GPG keypair to sign the release using the RSA algorithm:
```shell
gpg --full-generate-key
```

- Export the public gpg key:
```shell
gpg -o gpg-key.pub -a --export <your.name@email.com>
```

- Unzip the provider file downloaded previously for MacOS:
```shell
cd registry.terraform.io/vmware/vra

unzip terraform-provider-vra_0.7.1_darwin_amd64.zip
```

- Rename the extracted binary with the name you want to define for your private provider `vra2`:
```shell
mv terraform-provider-vra_v0.7.1 /Users/daniela/Downloads/private-provider-tfc/terraform-provider-vra2_v0.7.1
```

- Go back to the parent directory:
```shell
cd /Users/daniela/Downloads/private-provider-tfc
```

- Create a zip file with the new provider `vra2` binary:
```shell
zip terraform-provider-vra2_0.7.1_darwin_amd64.zip terraform-provider-vra2_v0.7.1
```

- Create a file with the shasums for the binaries of the new provider `vra2` and the version 0.7.1:
```shell
shasum -a 256 terraform-provider-vra2_0.7.1_darwin_amd64.zip > terraform-provider-vra2_0.7.1_SHA256SUMS
```

Note that a file `terraform-provider-vra2_0.7.1_SHA256SUMS` has been created 

- Create a detached signature using a gpg key:
```shell
gpg -sb terraform-provider-vra2_0.7.1_SHA256SUMS
```

Note that a file `terraform-provider-vra2_0.7.1_SHA256SUMS.sig` has been created 

## Steps to publish the provider to the private registry of Terraform Cloud

- Export your API token from Terraform Cloud as an environment variable:
```shell
export TOKEN=ab....
```

- Create the payload file named `gpg-key-payload.json` for the GPG key and generate your `ascii-armor` value with the following command (where your gpg key is in the file `gpg-key,pub):
```shell
sed 's/$/\\n/g' gpg-key.pub | tr -d '\n\r'
```

- The payload json file `gpg-key-payload.json` should look like this:
```
{
  "data": {
    "type": "gpg-keys",
    "attributes": {
      "namespace": "<your-org>",
      "ascii-armor": "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nmI0E...6L\n-----END PGP PUBLIC KEY BLOCK-----\n"
    }   
  }
}
```

- Add the GPG key to the private registry of the Terraform Cloud:
```shell
curl -sS \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request POST \
    --data @gpg-key-payload.json \
    https://app.terraform.io/api/registry/private/v2/gpg-keys | jq '.'

{
  "data": {
    "type": "gpg-keys",
    "id": "726",
    "attributes": {
      "ascii-armor": "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nm....L\n-----END PGP PUBLIC KEY BLOCK-----\n",
      "created-at": "2023-03-15T12:16:05Z",
      "key-id": "F5....46",
      "namespace": "<your-org>",
      "source": "",
      "source-url": null,
      "trust-signature": "",
      "updated-at": "2023-03-15T12:16:05Z"
    },
    "links": {
      "self": "/v2/gpg-keys/726"
    }
  }
}
```

Save the value of the `key-id`: `F5E1C817C4E028D4`

- Create the payload file named `provider-payload.json`:
```
{
  "data": {
    "type": "registry-providers",
      "attributes": {
      "name": "vra2",
      "namespace": "<your-org>",
      "registry-name": "private"
    }
  }
}
```

- Create the provider `vra2` in the private registry of Terraform Cloud
```shell
curl -sS \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @provider-payload.json \
  https://app.terraform.io/api/v2/organizations/daniela-org/registry-providers | jq '.'
  ```

- Create the payload file named `provider-version-payload.json` for the version:
```
{
  "data": {
    "type": "registry-provider-versions",
    "attributes": {
      "version": "0.7.1",
      "key-id": "<your-gpg-key-id>",
      "protocols": ["5.0"]
    }
  }
}
```

- Create the provider version in the private registry of Terraform Cloud:
```shell
curl -sS \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @provider-version-payload.json \
  https://app.terraform.io/api/v2/organizations/<YOUR-TFC-ORG>/registry-providers/private/<YOUR-TFC-ORG>/vra2/versions | jq '.'
```

- Save your URLs for `shasums-upload` and `shasums-sig-upload`:
```
    "links": {
      "shasums-upload": "https://archivist.terraform.io/v1/object/dmF1bHQ6djI6KzNkOHN4dkxnMTNxbGF3bGM1QS9MTFh1RktkaDQ5THJIU3BxVmt4RFhCdTBpMklHeHBCRmRvUm1Hc3g1MFJISGtTcjBwQUlXYW9Wd2RCZjNscEpyc0NNQjlrTEliRXlXVnRtRlc2aGJORE14T3JmU1EvUVZCWHdjaFY3TU1zZFV2eEhqSTVLTVdIZ1UyWEw5cU1ZeVdnbHV5VXFvQk5rbGRMWUl6Y0JIMk9JbUpPZVhPb0RZVHB2Z3d5Y1JBRk5oQXdwTm93cUFHOENnSmhxQTJsMVhiMlRLdEZQbVNTYytJMzhYV3dpQk9wM3FFcVVGMEJLYXlqblVnQzF6aTJCcWZ5RDBxem5ubExNdk52YlB1aWd5NzFNSmlrQlA5czFnUUZIdUdUUnliK0k9",
      "shasums-sig-upload": "https://archivist.terraform.io/v1/object/dmF1bHQ6djI6akFNeHJuZUM1eWM5dmhOWlNlK1RUV05xQmtEYklJQ0JmTHNxcWVGemg3WGV6TGlXRHZXT1dOMEJDUmRUYWQzQTBpbFptVWljTGxvRnJsUnZMdjNlTGwva2toYkRZVmlXWk1MV1FCaXJESlROSmU2elFHWkYwa2Z2UjFMQjBFbEdjdDM2MUJ1WFRqc0Z1eVBoZy92ek9jQ3dPQmhBTHJLVlQ5VE9DbElIcmFQa0VjQ0pPWmlVRkdsUDBLVGpOSExON2tmZ3h1dnVva0dhRU9XcHdKZzlSOUZQQjdDS1NLUEMxZEk1RHc0WjBhTDJwKzd2cUVWUUpLbUFGQzdnWWtGNFNpOGM5NzVBb0JaYmZRK1cxZ1NyWTl2aUQzWUJKQ1ZLMTA4RjdQeEVTQ29QaTMvcQ"
```

- Upload the `shasum` file to the URL:
```shell
curl -T terraform-provider-vra2_0.7.1_SHA256SUMS https://archivist.terraform.io/v1/object/dmF1bHQ6djI6KzNkOHN4dkxnMTNxbGF3bGM1QS9MTFh1RktkaDQ5THJIU3BxVmt4RFhCdTBpMklHeHBCRmRvUm1Hc3g1MFJISGtTcjBwQUlXYW9Wd2RCZjNscEpyc0NNQjlrTEliRXlXVnRtRlc2aGJORE14T3JmU1EvUVZCWHdjaFY3TU1zZFV2eEhqSTVLTVdIZ1UyWEw5cU1ZeVdnbHV5VXFvQk5rbGRMWUl6Y0JIMk9JbUpPZVhPb0RZVHB2Z3d5Y1JBRk5oQXdwTm93cUFHOENnSmhxQTJsMVhiMlRLdEZQbVNTYytJMzhYV3dpQk9wM3FFcVVGMEJLYXlqblVnQzF6aTJCcWZ5RDBxem5ubExNdk52YlB1aWd5NzFNSmlrQlA5czFnUUZIdUdUUnliK0k9
```

- Upload the `shasum sig` file to the URL:
```shell
curl -T terraform-provider-vra2_0.7.1_SHA256SUMS.sig https://archivist.terraform.io/v1/object/dmF1bHQ6djI6akFNeHJuZUM1eWM5dmhOWlNlK1RUV05xQmtEYklJQ0JmTHNxcWVGemg3WGV6TGlXRHZXT1dOMEJDUmRUYWQzQTBpbFptVWljTGxvRnJsUnZMdjNlTGwva2toYkRZVmlXWk1MV1FCaXJESlROSmU2elFHWkYwa2Z2UjFMQjBFbEdjdDM2MUJ1WFRqc0Z1eVBoZy92ek9jQ3dPQmhBTHJLVlQ5VE9DbElIcmFQa0VjQ0pPWmlVRkdsUDBLVGpOSExON2tmZ3h1dnVva0dhRU9XcHdKZzlSOUZQQjdDS1NLUEMxZEk1RHc0WjBhTDJwKzd2cUVWUUpLbUFGQzdnWWtGNFNpOGM5NzVBb0JaYmZRK1cxZ1NyWTl2aUQzWUJKQ1ZLMTA4RjdQeEVTQ29QaTMvcQ
```

- Create the payload file named `provider-version-payload-platform.json`:
```
{
  "data": {
    "type": "registry-provider-version-platforms",
    "attributes": {
      "os": "darwin",
      "arch": "amd64",
      "shasum": "<shasum of the binary archive terraform-provider-vra2_0.7.1_SHA256SUMS>",
      "filename": "terraform-provider-vra2_0.7.1_darwin_amd64.zip"
    }
  }
}
```

- Create the provider version platform:
```shell
curl -sS \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @provider-version-payload-platform.json \
  https://app.terraform.io/api/v2/organizations/daniela-org/registry-providers/private/daniela-org/vra2/versions/0.7.1/platforms | jq '.'
```

- Save the value of the `provider-binary-upload` from the response:
```
 "provider-binary-upload": "https://archivist.terraform.io/v1/object/dmF1bHQ6djI6K2M3Tkp6c1VsazhncHhhRnhOcWdHTGFIMlAwWW9SVHc3MEV3YzllK1BpbzVydlZhdU5rT0hPVUF0N2J1YVhjbE84R0lRQWdkbEt6cmduL1JRaHErRXljZFp5dHdTTlRlL2c5NlVyVTBvM0xVdXJlTFg3UFdPMHh4bC9Tb1JYdXNjejdiTStIcGFaRXhTM1JwMEpFenVKcm9TenFyTzV1RENhSk03b3RxaHRRYURoV0duTjBHTEFMdG4vdDdRY0xvYnhxbEplcTF4WWg2Tjh1T2xiWHdxL2NZQjBjOE5tK2tKVUlSTEY4V0VwQXd0U3dOdWltZU5ZVVlYOW93aEE9PQ"
    }
```

- Upload the archived binary to the `provider-binary-upload` URL:
```shell
curl -T terraform-provider-vra2_0.7.1_darwin_amd64.zip https://archivist.terraform.io/v1/object/dmF1bHQ6djI6K2M3Tkp6c1VsazhncHhhRnhOcWdHTGFIMlAwWW9SVHc3MEV3YzllK1BpbzVydlZhdU5rT0hPVUF0N2J1YVhjbE84R0lRQWdkbEt6cmduL1JRaHErRXljZFp5dHdTTlRlL2c5NlVyVTBvM0xVdXJlTFg3UFdPMHh4bC9Tb1JYdXNjejdiTStIcGFaRXhTM1JwMEpFenVKcm9TenFyTzV1RENhSk03b3RxaHRRYURoV0duTjBHTEFMdG4vdDdRY0xvYnhxbEplcTF4WWg2Tjh1T2xiWHdxL2NZQjBjOE5tK2tKVUlSTEY4V0VwQXd0U3dOdWltZU5ZVVlYOW93aEE9PQ
```

- The `vra2` provider is now uploaded in the Terraform Cloud's private registry:
![Vra2 TFC private registry](https://github.com/dlavric/private-provider-tfc/blob/main/pictures/private-registry-tfc-vra2.png)

## Verify the private provider works 

- Create a new workspace with a CLI-driven workflow in your Terraform Cloud UI:

- Create a `main.tf` file locally with the following content:
```
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
```

- Login to Terraform Cloud through your terminal:
```shell
terraform login
```

- Initialize terraform to download the dependencies of the `vra2` private provider:
```shell
terraform init

Initializing Terraform Cloud...

Initializing provider plugins...
- Finding app.terraform.io/daniela-org/vra2 versions matching "0.7.1"...
- Installing app.terraform.io/daniela-org/vra2 v0.7.1...
- Installed app.terraform.io/daniela-org/vra2 v0.7.1 (self-signed, key ID F5E1C817C4E028D4)

Partner and community providers are signed by their developers.
If you'd like to know more about provider signing, you can read about it here:
https://www.terraform.io/docs/cli/plugins/signing.html

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform Cloud has been successfully initialized!

You may now begin working with Terraform Cloud. Try running "terraform plan" to
see any changes that are required for your infrastructure.

If you ever set or change modules or Terraform Settings, run "terraform init"
again to reinitialize your working directory.
```



