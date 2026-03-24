## Generate cockpit data sources and tokens

Console: https://console.scaleway.com/cockpit

After creating the log resources, add a dashboard following https://www.scaleway.com/en/docs/cockpit/how-to/send-metrics-logs-to-cockpit/.

```bash

terraform init
terraform plan
terraform apply -auto-approve
```

### Record tokens and API keys for use in instances, apps

```bash
python get_cockpit_config.py
```

```python
import logging
import logging_loki
import time

# export COCKPIT_LOG_URL=https://XXX.logs.cockpit.fr-par.scw.cloud
# export COCKPIT_API_KEY=11111111-1111-1111-1111-111111111111
# export COCKPIT_LOG_TOKEN=XXX

handler = logging_loki.LokiHandler(
    url="https://XXX.logs.cockpit.fr-par.scw.cloud/loki/api/v1/push",
    tags={"job": "logs_from_python"},
    auth=("11111111-1111-1111-1111-111111111111", "XXXXXXXX"),
    version="1",
)

log_formatter = logging.Formatter(
    "%(name)s - %(levelname)s -  %(message)s"
)
handler.setLevel(logging.DEBUG)
handler.setFormatter(log_formatter)

logger = logging.getLogger("my-first-python-logger")
logger.addHandler(handler)
```

Or generate a logger with this helper:

```python
import get_cockpit_config
logger = get_cockpit_config.get_cockpit_config()
logger.warning("This is your first warning!")
```