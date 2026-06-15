This is the code that is actually run on the instance.

For example, the [cloud-init.yml](../terraform/cloud-init.yml) script will set the `crontab` on each instance to run the command below every minute, which polls for `status=0` associations to preprocess.

```bash
conda run -n py312 python3 /root/scaleway-dja/processor-instance/app/app.py --assoc
```
