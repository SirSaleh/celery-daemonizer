# celery-daemonizer
simple scripts to daemonize celery apps. currently it is only available for
python apps.

# usage


```
sh start.sh <options>
```

**Note**: start.sh need the root access. So you if you are not using the root user, you will probably need to use
`sudo`.

## list of options

| option | description | required/optional |
| ----   | ----------- | ----------------- |
| -a     | celery app (for example my_main_app.celery:app) | required |
| -c     | your app ch-dir, for example `/srv/my-proj/` | required |
| -d     | celery run dir for example `/home/saleh/.local/bin/celery`. maybe `which celery` can help you | required |
| -n     | your app name, for example `my_app` | required |