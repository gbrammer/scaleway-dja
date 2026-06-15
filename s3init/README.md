# Set up environment for the awscli s3api

```bash
pip install awscli
```

Instructions at https://www.scaleway.com/en/docs/object-storage/api-cli/object-storage-aws-cli/.

For a profile named `$PROFILE` stored in the `~/.aws/credentals` file, put the following in `~/.aws/config`, which can live alongside other AWS profiles:

```bash
[profile $PROFILE]
region = fr-par
output = text
services = scw-fr-par

[services scw-fr-par]
s3 =
  endpoint_url = https://s3.fr-par.scw.cloud
  max_concurrent_requests = 100
  max_queue_size = 1000
  multipart_threshold = 50 MB
  multipart_chunksize = 10 MB
s3api =
  endpoint_url = https://s3.fr-par.scw.cloud
```

Add a BASH alias to the `awscli --profile` (in `~/.bashrc`):

```bash
$ alias saws="aws --profile $PROFILE"
```

Then you should be able to run, e.g.,

```bash
$ saws s3 ls
2026-03-18 09:39:25 dja-cloud

$ saws s3 ls s3://dja-cloud/scratch
                           PRE grism/
2026-03-18 10:39:52         29 date.txt
2026-03-26 12:37:25         29 junk.txt
```
