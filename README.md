## INTRODUCTION

Docker image of [suricata](https://suricata.io/)

Implements Mikrotik Calea traffic inspection via via trafr.

## INSTALL

```mkdir $HOME/suricata```

```docker run -it --name suricata -v $HOME/suricata/etc:/etc/suricata  -v $HOME/suricata/logs:/var/log/suricata --network host --restart always grinco/trafr-suricata```

