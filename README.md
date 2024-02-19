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
    oci = {
      source = "oracle/oci"
      version = "5.29.0"
    }
  }
}

provider "oci" {
  # Configuration options
}
``` 

- Download the provider files to a directory on your local machine:
```shell
terraform providers mirror ./

- Mirroring oracle/oci...
  - Selected v5.29.0 to meet constraints 5.29.0
  - Downloading package for darwin_amd64...
  - Package authenticated: signed by a HashiCorp partner
```

Observe that a new folder named `registry.terraform.io` has been created and it contains the `oci` provider.

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
output
```
gpg (GnuPG) 2.4.3; Copyright (C) 2023 g10 Code GmbH
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Please select what kind of key you want:
   (1) RSA and RSA
   (2) DSA and Elgamal
   (3) DSA (sign only)
   (4) RSA (sign only)
   (9) ECC (sign and encrypt) *default*
  (10) ECC (sign only)
  (14) Existing key from card
Your selection? 1
RSA keys may be between 1024 and 4096 bits long.
What keysize do you want? (3072) 
Requested keysize is 3072 bits
Please specify how long the key should be valid.
         0 = key does not expire
      <n>  = key expires in n days
      <n>w = key expires in n weeks
      <n>m = key expires in n months
      <n>y = key expires in n years
Key is valid for? (0) 
Key does not expire at all
Is this correct? (y/N) y

GnuPG needs to construct a user ID to identify your key.

Real name: patrick_oci
Email address: patrick_oci@test_oci.com
Comment: testing
You selected this USER-ID:
    "patrick_oci (testing) <patrick_oci@test_oci.com>"

Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit? O
We need to generate a lot of random bytes. It is a good idea to perform
some other action (type on the keyboard, move the mouse, utilize the
disks) during the prime generation; this gives the random number
generator a better chance to gain enough entropy.
We need to generate a lot of random bytes. It is a good idea to perform
some other action (type on the keyboard, move the mouse, utilize the
disks) during the prime generation; this gives the random number
generator a better chance to gain enough entropy.
gpg: revocation certificate stored as '/Users/patrickmunne/.gnupg/openpgp-revocs.d/121AD89CA07D84F400480621CB3AD3052843121E.rev'
public and secret key created and signed.

pub   rsa3072 2024-02-19 [SC]
      121AD89CA07D84F400480621CB3AD3052843121E
uid                      patrick_oci (testing) <patrick_oci@test_oci.com>
sub   rsa3072 2024-02-19 [E]
```

- Export the public gpg key:
```shell
gpg -o gpg-key.pub -a --export <your.name@email.com>
```

- Unzip the provider file downloaded previously for MacOS:
```shell
cd registry.terraform.io/oracle/oci

unzip terraform-provider-oci_5.29.0_darwin_amd64.zip
```

- Rename the extracted binary with the name you want to define for your private provider `oci`:
```shell
mv terraform-provider-oci_v5.29.0 ../../../
```

- Go back to the parent directory:
```shell
cd ../../../
```

- Create a zip file with the new provider `oci` binary:
```shell
zip terraform-provider-oci_5.29.0_darwin_amd64.zip terraform-provider-oci_v5.29.0
```

- Create a file with the shasums for the binaries of the new provider `vra2` and the version 0.7.1:
```shell
shasum -a 256 terraform-provider-oci_5.29.0_darwin_amd64.zip > terraform-provider-oci_5.29.0_darwin_SHA256SUMS
```

Note that a file `terraform-provider-oci_5.29.0_darwin_SHA256SUMS` has been created 

- Create a detached signature using a gpg key:
```shell
gpg -sb terraform-provider-oci_5.29.0_darwin_SHA256SUMS
```

Note that a file `terraform-provider-oci_5.29.0_darwin_SHA256SUMS.sig` has been created 

## Steps to publish the provider to the private registry of Terraform Cloud

- Export your API token from Terraform Cloud as an environment variable:
```shell
export TOKEN=0zGXzPqxHtbqUg.atlasv1.xxxxxxxx
```

- Create the payload file named `gpg-key-payload.json` for the GPG key and generate your `ascii-armor` value with the following command (where your gpg key is in the file `gpg-key.pub):
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
    https://tfe67.aws.munnep.com/api/registry/private/v2/gpg-keys | jq '.'

{
  "data": {
    "type": "gpg-keys",
    "id": "4",
    "attributes": {
      "ascii-armor": "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nmQGNBGXTY24BDADSXDCMGiR80JDrNfEua4/n=wVNT\n-----END PGP PUBLIC KEY BLOCK-----\n",
      "created-at": "2024-02-19T14:27:43Z",
      "key-id": "CB3AD3052843121E",
      "namespace": "test",
      "source": "",
      "source-url": null,
      "trust-signature": "",
      "updated-at": "2024-02-19T14:27:43Z"
    },
    "links": {
      "self": "/v2/gpg-keys/4"
    }
  }
}
```

Save the value of the `key-id`: `CB3AD3052843121E`

- Create the payload file named `provider-payload.json`:
```
{
    "data": {
      "type": "registry-providers",
        "attributes": {
        "name": "oci",
        "namespace": "test",
        "registry-name": "private"
      }
    }
  }
```

- Create the provider `oci` in the private registry of Terraform Cloud/Enterprise
```shell
curl -sS \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @provider-payload.json \
  https://tfe67.aws.munnep.com/api/v2/organizations/test/registry-providers | jq '.'
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
  https://tfe67.aws.munnep.com/api/v2/organizations/test/registry-providers/private/test/oci/versions | jq '.'
```

- Save your URLs for `shasums-upload` and `shasums-sig-upload`:
```
     "shasums-upload": "https://tfe67.aws.munnep.com/_archivist/v1/object/dmF1bHQ6djE6QmY0QWNxK25HcXFBT1ZWNzJDSGxFc3pFRmsrbG40QW9DR3htaHlQTnhhbHp1RUJWL0Jsb3MyanlEbGVlUmNEZ3UyemN5ZERJU0FkNnFBSjkwWWFzQVUrQjVhekhCVzdMSjU1QXBESzM1M3Q5UGc5NnRrTUZLbEhjYmpNcHEzdnVtS1EzRXVaZ1BnWHdaMTRKSDNmdDdIVmxiSFhaRWZwZGlVWnVvWjVHTEh1Z0xHdXBuR01nT01jSkc3blpwbEswcTROOTlSd3VRQU0ycTAzSnhZZk45Y2pBTGFXeGVabWRwY0s0MnQ5RnBFQVF2aTZZTFk4SWV6SFJIbW92OGZuYUVvRDBPRjBKQ2JwRk42c1JrSlAvaFdWdXd3cWFZV3RSUk1ENmJyOTlFbGs9",
      "shasums-sig-upload": "https://tfe67.aws.munnep.com/_archivist/v1/object/dmF1bHQ6djE6QTlBNTRVUDd2eXRlT0syeWZlNDBpZi9qdDlEdWxoN1lxdzhMc0JGcFE4cXFuNHhPanVZV1FZbzZESy9GWmQ3SFBuandOUVJ5eTFSOXhWZ3FjK1V4dHdGVjFGbDl1NHVYTzBMMzR6dnZZN0lXKzJ3LzRUdU9zYzZpbkZzOHBEZEM4czNDWEgwRXlTS3ZEb0ZTMys1V2FseGVHaVYwNHZHdFFwaGlYb2d6SWlRQThlUHcrRjFTRGM5Z0dEbWFpb0FldmNpd283MHFtQTNyVjBFUkp3WGduWXdtSEVnQVFZa3VBKytUeTVNV1p6cFFDSkRrSFg0MkxWVit0alpDd3E0Y3ZPZC90VnIvRVArUkF1cXhPU3lxOEIvd3pGOG8xbVFNZU44K3MraHlxaUUwT3ZIVA"
   
```

- Upload the `shasum` file to the URL:
```shell
curl -T terraform-provider-oci_5.29.0_darwin_SHA256SUMS https://tfe67.aws.munnep.com/_archivist/v1/object/dmF1bHQ6djE6QmY0QWNxK25HcXFBT1ZWNzJDSGxFc3pFRmsrbG40QW9DR3htaHlQTnhhbHp1RUJWL0Jsb3MyanlEbGVlUmNEZ3UyemN5ZERJU0FkNnFBSjkwWWFzQVUrQjVhekhCVzdMSjU1QXBESzM1M3Q5UGc5NnRrTUZLbEhjYmpNcHEzdnVtS1EzRXVaZ1BnWHdaMTRKSDNmdDdIVmxiSFhaRWZwZGlVWnVvWjVHTEh1Z0xHdXBuR01nT01jSkc3blpwbEswcTROOTlSd3VRQU0ycTAzSnhZZk45Y2pBTGFXeGVabWRwY0s0MnQ5RnBFQVF2aTZZTFk4SWV6SFJIbW92OGZuYUVvRDBPRjBKQ2JwRk42c1JrSlAvaFdWdXd3cWFZV3RSUk1ENmJyOTlFbGs9
```

- Upload the `shasum sig` file to the URL:
```shell
curl -T terraform-provider-oci_5.29.0_darwin_SHA256SUMS.sig https://tfe67.aws.munnep.com/_archivist/v1/object/dmF1bHQ6djE6QTlBNTRVUDd2eXRlT0syeWZlNDBpZi9qdDlEdWxoN1lxdzhMc0JGcFE4cXFuNHhPanVZV1FZbzZESy9GWmQ3SFBuandOUVJ5eTFSOXhWZ3FjK1V4dHdGVjFGbDl1NHVYTzBMMzR6dnZZN0lXKzJ3LzRUdU9zYzZpbkZzOHBEZEM4czNDWEgwRXlTS3ZEb0ZTMys1V2FseGVHaVYwNHZHdFFwaGlYb2d6SWlRQThlUHcrRjFTRGM5Z0dEbWFpb0FldmNpd283MHFtQTNyVjBFUkp3WGduWXdtSEVnQVFZa3VBKytUeTVNV1p6cFFDSkRrSFg0MkxWVit0alpDd3E0Y3ZPZC90VnIvRVArUkF1cXhPU3lxOEIvd3pGOG8xbVFNZU44K3MraHlxaUUwT3ZIVA
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
  https://tfe67.aws.munnep.com/api/v2/organizations/test/registry-providers/private/test/oci/versions/5.29.0/platforms | jq '.'
```

- Save the value of the `provider-binary-upload` from the response:
```
      "provider-binary-upload": "https://tfe67.aws.munnep.com/_archivist/v1/object/dmF1bHQ6djE6T2pvQmdJaFRlNWRxY08yTmJTR2JZbmdvOC9pbXQwWHRnNFhveGtJYmFZZG5iZjJrZUp6WVJ6dHMzdUZxZG9iSWMvTm1UYTBIOXVWOCs5UVhGNnlJRlVGUVhOQWhERUpPdTd2VTRiU1haazhqQUxnSGorVlhVOFlmL2dOUS8wQjVWNGNyYmVPRjZLZjBsZWw1T0xmVHZ1QjhPbitSbVF1b00yUWNEamtWa1BZTUtyM3RkMnozNkRhTGhYSUhzZGZ2bVdwYmNkR0FmYTJreFh3enFZN1Bkcy9tTVZZRjd4dFVpTFVIVStIMEVmSzR1RENFdS83U0Z1b3hRL2pIRFE9PQ"
    }
    }
```

- Upload the archived binary to the `provider-binary-upload` URL:
```shell
curl -T terraform-provider-oci_5.29.0_darwin_amd64.zip https://tfe67.aws.munnep.com/_archivist/v1/object/dmF1bHQ6djE6T2pvQmdJaFRlNWRxY08yTmJTR2JZbmdvOC9pbXQwWHRnNFhveGtJYmFZZG5iZjJrZUp6WVJ6dHMzdUZxZG9iSWMvTm1UYTBIOXVWOCs5UVhGNnlJRlVGUVhOQWhERUpPdTd2VTRiU1haazhqQUxnSGorVlhVOFlmL2dOUS8wQjVWNGNyYmVPRjZLZjBsZWw1T0xmVHZ1QjhPbitSbVF1b00yUWNEamtWa1BZTUtyM3RkMnozNkRhTGhYSUhzZGZ2bVdwYmNkR0FmYTJreFh3enFZN1Bkcy9tTVZZRjd4dFVpTFVIVStIMEVmSzR1RENFdS83U0Z1b3hRL2pIRFE9PQ
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



