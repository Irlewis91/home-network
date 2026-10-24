# 11. Wazuh: a security monitoring system (SIEM)

**Goal:** collect security events from every device in one place: logins, file changes, known vulnerabilities, suspicious activity. Searchable in a web dashboard.

**Time:** about 15 minutes, mostly waiting.

## Why Wazuh and not Wazuh plus ELK

Wazuh already includes an ELK-style stack: its **indexer** is a fork of Elasticsearch (OpenSearch), and its **dashboard** is a fork of Kibana. Running a second, separate ELK stack beside it would mean two Java search engines fighting over 8 GB of RAM. Wazuh alone covers both jobs.

| Part | Job |
|---|---|
| Wazuh indexer | Stores and searches events (OpenSearch) |
| Wazuh manager | Receives events from agents and applies the detection rules |
| Filebeat | Ships the manager's alerts into the indexer |
| Wazuh dashboard | The web interface (OpenSearch Dashboards) |

## Step 1: install everything on one machine

```bash
curl -fsSL -o wazuh-install.sh https://packages.wazuh.com/4.14/wazuh-install.sh
sudo bash wazuh-install.sh -a -i
```

- `-a` installs all four parts on this machine.
- `-i` skips the hardware check. The installer's list of supported systems ends at Ubuntu 24.04, but for newer versions it only warns; it worked on 26.04.

**Don't create `/var/lib/wazuh-indexer` before installing.** I made it ahead of time to put the data on the big drive, and the installer stopped immediately with `Wazuh indexer already installed`. Install first, move the data afterward.

## Step 2: move the search data to the big drive

The internal SSD is small. The indexer's data goes to the 2TB drive through a bind mount:

```bash
sudo systemctl stop wazuh-dashboard filebeat wazuh-indexer
sudo mkdir -p /srv/storage/wazuh-indexer
sudo rsync -aHAX /var/lib/wazuh-indexer/ /srv/storage/wazuh-indexer/
sudo mv /var/lib/wazuh-indexer /var/lib/wazuh-indexer.old && sudo mkdir /var/lib/wazuh-indexer
sudo chown --reference=/var/lib/wazuh-indexer.old /var/lib/wazuh-indexer /srv/storage/wazuh-indexer
echo "/srv/storage/wazuh-indexer /var/lib/wazuh-indexer none bind,nofail,x-systemd.requires=/srv/storage 0 0" | sudo tee -a /etc/fstab
sudo mkdir -p /etc/systemd/system/wazuh-indexer.service.d
printf "[Unit]\nRequiresMountsFor=/var/lib/wazuh-indexer\n" | sudo tee /etc/systemd/system/wazuh-indexer.service.d/storage.conf
sudo systemctl daemon-reload && sudo mount /var/lib/wazuh-indexer
sudo systemctl start wazuh-indexer && sleep 20 && sudo systemctl start filebeat wazuh-dashboard
```

`RequiresMountsFor` makes sure the indexer never starts on an empty folder if the drive is unplugged.

![Wazuh running, data on the 2TB drive](../screenshots/18-wazuh.png)

Memory: with everything running, the server uses about 4 GB of its 7.2 GB. The installer set the indexer's Java heap to 1 GB, which is plenty for a home network.

## Step 3: log in

The dashboard is at `https://<server-ip>` at home, or `https://homeserver` over Tailscale. The certificate is self-signed, so the browser warns once.

The installer generates the passwords and keeps them in a root-only archive. Read the admin password yourself, so it never ends up in a log or chat:

```bash
ssh -t <server-user>@<server-ip> "sudo tar -O -xf /root/wazuh/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt" | grep -A1 "username: 'admin'"
```

Store it in a password manager.

## Step 4: agents

The manager monitors the server itself from the start (agent `000`). Other devices need the Wazuh agent:

- **Main Mac:** the macOS agent package, pointed at the server. (Next step.)
- **Android:** there is no Wazuh agent for Android. Its logs can be forwarded later over syslog.
