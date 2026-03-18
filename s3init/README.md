Instructions at https://www.scaleway.com/en/docs/object-storage/api-cli/object-storage-aws-cli/.

For a profile named `$PROFILE`, in config:

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

# then
$ saws s3 ls
2026-03-18 09:39:25 dja-cloud
```