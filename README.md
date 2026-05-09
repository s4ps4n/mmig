# Mail VDS Migration Kit

Набор скриптов и руководство для переноса корпоративной почты на свой VDS:

- Postfix - SMTP, входящая и исходящая почта
- Dovecot - IMAP и хранение Maildir
- Roundcube - веб-почта
- imapsync - перенос писем со старого IMAP
- OpenDKIM - DKIM-подпись исходящих писем
- DNS - A, MX, SPF, DKIM, DMARC, PTR

Главное правило: сначала поднимаем и проверяем новый сервер, потом делаем финальный sync, и только после этого переключаем MX.

## Быстрый старт

```bash
cp config.env.example config.env
nano config.env

cp mailboxes.csv.example /root/mail-migration/mailboxes.csv
nano /root/mail-migration/mailboxes.csv

scripts/00-check-env.sh
scripts/01-install-packages.sh
scripts/02-configure-dovecot.sh
scripts/03-configure-postfix.sh
scripts/04-create-mailboxes.sh
scripts/05-sync-mailboxes.sh
```

Перед запуском производственных скриптов в `config.env` нужно поставить:

```bash
CONFIRM_PRODUCTION="yes"
```

Это не защита от всех бед. Это хотя бы маленький лежачий полицейский перед тем, как вы въедете в боевой сервер.

## Что читать

Полное руководство:

```text
GUIDE.md
```

Примеры DNS:

```text
docs/dns-records.example.md
```

Скрипты администрирования ящиков:

```text
admin/list-mailboxes.sh
admin/create-mailbox.sh
admin/change-password.sh
admin/disable-mailbox.sh
admin/quota-report.sh
```

## Важно

Скрипты рассчитаны на схему с файловыми пользователями:

```text
/etc/dovecot/users
/etc/postfix/vmailbox
/etc/postfix/vdomains
/var/vmail/<domain>/<user>/Maildir
```

Это не PostfixAdmin, не Mailcow и не iRedMail. Это более простой и контролируемый вариант для ситуации, когда почту нужно поднять рядом с уже живущим сервером.

Перед использованием на проде прочитайте `GUIDE.md` целиком. Особенно разделы про DNS, Roundcube, BitrixVM и финальное переключение MX.

## Источники

- Postfix Virtual Domain Hosting Howto: https://www.postfix.org/VIRTUAL_README.html
- Postfix virtual mailbox delivery: https://www.postfix.org/virtual.8.html
- Dovecot passwd-file: https://doc.dovecot.org/main/core/config/auth/databases/passwd_file.html
- Roundcube configuration: https://github.com/roundcube/roundcubemail/wiki/Configuration
- imapsync official site: https://imapsync.lamiral.info/
- imapsync folder mapping and regextrans2: https://imapsync.lamiral.info/FAQ.d/FAQ.Folders_Mapping.txt
- OpenDKIM README: https://www.opendkim.org/opendkim-README
- OpenDKIM config manual: https://www.opendkim.org/opendkim.conf.5.html
