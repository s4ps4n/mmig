# Как перенести корпоративную почту на свой VDS и не сжечь бизнес-процесс

Почта выглядит простой ровно до момента, пока ее не нужно перенести.

На уровне фантазии это звучит так:

```text
скопировали письма
поменяли MX
все работает
```

На уровне реальности появляются пароли приложений, Dovecot, Postfix, SPF, DKIM, DMARC, PTR, Roundcube, папки с кривыми именами и бухгалтерия, которая просто хочет отправить счет.

**Главная мысль: почтовая миграция - это не перенос файлов. Это операция на живом бизнесе.**

Делать ее надо спокойно, по шагам и без героизма.

## 1. Что собираем

Итоговая схема:

```text
Почтовый домен: example.ru
Почтовый сервер: mail.example.ru
IP сервера: 203.0.113.10

Ящики:
info@example.ru
order@example.ru
buh@example.ru
manager@example.ru
```

Компоненты:

```text
Postfix - принимает и отправляет почту
Dovecot - IMAP и хранение Maildir
Roundcube - веб-интерфейс
imapsync - перенос писем со старого IMAP
OpenDKIM - DKIM-подпись исходящих писем
DNS - A, MX, SPF, DKIM, DMARC, PTR
```

`mail.example.ru` - это технический хост.

Письма отправляются от нормальных адресов:

```text
info@example.ru
order@example.ru
buh@example.ru
```

Не от `info@mail.example.ru`. Это разные вещи. Не путайте, а то потом будете искать ошибку там, где ее нет.

## 2. Правильный порядок работ

Не начинайте с MX.

Правильный порядок:

```text
1. Поднять сервер
2. Настроить Postfix и Dovecot
3. Создать ящики
4. Перенести письма через imapsync
5. Поднять Roundcube
6. Выпустить SSL
7. Настроить SMTP 465/587 и IMAP 993
8. Настроить SPF, DKIM, DMARC, PTR
9. Проверить отправку и получение
10. Сделать финальный sync
11. Переключить MX
12. Через 30-60 минут сделать контрольный sync
```

Кто сначала меняет MX, а потом начинает читать логи Dovecot, тот не системный администратор, а ведущий реалити-шоу.

## 3. Конфигурация проекта

Скопируйте конфиг:

```bash
cp config.env.example config.env
nano config.env
```

Пример:

```bash
DOMAIN="example.ru"
MAIL_HOST="mail.example.ru"
SERVER_IP="203.0.113.10"
OLD_IMAP_HOST="imap.old-provider.example"
MAILBOXES_CSV="/root/mail-migration/mailboxes.csv"
CONFIRM_PRODUCTION="yes"
```

CSV с ящиками:

```bash
mkdir -p /root/mail-migration
cp mailboxes.csv.example /root/mail-migration/mailboxes.csv
nano /root/mail-migration/mailboxes.csv
```

Формат:

```csv
email,app_password,new_password,maxage
info@example.ru,OLD_APP_PASSWORD,NewPassword123!,30
order@example.ru,OLD_APP_PASSWORD,NewPassword123!,30
buh@example.ru,OLD_APP_PASSWORD,NewPassword123!,90
```

`maxage` - за сколько дней забирать почту.

Это удобно, когда у одного ящика 200 тысяч писем, а бизнесу прямо сейчас нужны последние 30 дней, а не археологическая экспедиция за 2016 год.

## 4. Проверка окружения

```bash
scripts/00-check-env.sh
```

Смотрим:

```text
какой домен
какой mail host
какие порты уже заняты
виден ли CSV
есть ли базовые команды
```

Если на сервере уже живут боевые сайты, особенно на BitrixVM, не делайте вид, что это чистый сервер. Он не чистый. Он уже чей-то источник денег.

Перед изменениями:

```bash
tar -czf /root/before-mail-migration-$(date +%F_%H-%M-%S).tar.gz \
/etc/nginx \
/etc/httpd \
/etc/postfix \
/etc/dovecot 2>/dev/null
```

## 5. Установка пакетов

```bash
scripts/01-install-packages.sh
```

Скрипт ставит:

```text
Postfix
Dovecot
imapsync
Roundcube-зависимости PHP
OpenDKIM
certbot
firewalld
```

Если на сервере кастомный PHP, Remi, BitrixVM и прочие радости, проверяйте PHP-модули:

```bash
php -m | egrep -i 'pdo|sqlite|imap|mbstring|intl|zip|mysqli|mysqlnd'
```

Roundcube на SQLite требует:

```text
PDO
pdo_sqlite
sqlite3
```

Если их нет, будет прекрасное:

```text
Oops... something went wrong
```

И в логах:

```text
Class "PDO" not found
```

## 6. Dovecot

Настройка:

```bash
scripts/02-configure-dovecot.sh
```

Схема хранения:

```text
/var/vmail/example.ru/info/Maildir
/var/vmail/example.ru/order/Maildir
```

Пользователи:

```text
/etc/dovecot/users
```

Формат:

```text
info@example.ru:$6$HASH
```

Проверка:

```bash
dovecot -n | egrep -i 'mail_location|passwd-file|imaps|ssl|cert|key' -A3 -B3
ss -tulpn | egrep ':143|:993'
```

IMAPS должен быть так:

```text
inet_listener imaps {
  port = 993
  ssl = yes
}
```

Если `ssl = no`, то `openssl` на 993 не увидит сертификат. И будет не мистика, а обычная конфигурация.

## 7. Postfix

Настройка:

```bash
scripts/03-configure-postfix.sh
```

Схема:

```text
/etc/postfix/vdomains
/etc/postfix/vmailbox
```

Проверка:

```bash
postconf -n | egrep 'myhostname|mydomain|virtual_mailbox|sasl|tls|recipient_restrictions'
ss -tulpn | egrep ':25|:465|:587'
```

Должны слушаться:

```text
25 - входящая почта
465 - SMTPS
587 - submission
```

Если `25` слушает только `127.0.0.1`, внешний мир к вам не придет. Он и так не особо стремится, но тут вы сами закрыли дверь.

## 8. Создание ящиков

```bash
scripts/04-create-mailboxes.sh
```

Скрипт читает CSV и создает:

```text
логин в Dovecot
строку в Postfix vmailbox
Maildir на диске
```

Проверка одного ящика:

```bash
doveadm auth test info@example.ru 'NewPassword123!'
```

Норма:

```text
auth succeeded
```

Если вход не работает, не надо сразу чинить Roundcube. Сначала проверьте Dovecot напрямую.

## 9. Перенос писем через imapsync

```bash
scripts/05-sync-mailboxes.sh
```

Скрипт:

```text
берет ящики из CSV
подключается к старому IMAP
подключается к локальному Dovecot
переносит письма
пишет лог по каждому ящику
пишет общий sync-report
```

Проверка отчетов:

```bash
LASTREPORT=$(ls -t /root/mail-migration/logs/sync-report-*.txt | head -1)
echo "$LASTREPORT"
grep "FAIL:" "$LASTREPORT"
cat "$LASTREPORT"
```

Если `FAIL:` пустой, жить можно.

Старые ошибки в логах не пугайтесь проверять отдельно по свежему отчету. `grep -R FAIL logs/` найдет всю вашу историю, включая моменты, когда вы еще спорили с именами папок.

Проверка количества писем:

```bash
for d in /var/vmail/example.ru/*; do
  echo "$(basename "$d"): $(find "$d/Maildir" -type f 2>/dev/null | grep -E '/new/|/cur/' | wc -l)"
done
```

## 10. Roundcube

Для BitrixVM:

```bash
scripts/06-install-roundcube-bitrixvm.sh
```

Скрипт создает:

```text
/var/www/roundcube
Apache vhost в /etc/httpd/bx/conf/
nginx vhost в /etc/nginx/bx/site_avaliable/
```

Проверка:

```bash
httpd -S
curl -I -H "Host: mail.example.ru" http://127.0.0.1:8887/
curl -I http://mail.example.ru
```

Если получаете 404 и в логах:

```text
/var/www/html/index.php not found
```

значит Apache не попал в нужный vhost.

Лечится не шаманством, а командой:

```bash
httpd -S
```

Смотрите, на каком порту реально живут vhost. На BitrixVM это часто `127.0.0.1:8887`, а не `8888`.

### Частая ошибка Roundcube

Симптом:

```text
Oops... something went wrong
```

Лог:

```text
Unable to create file /var/www/roundcube/db/roundcube.sqlite because Permission denied
```

Проверяем пользователя Apache:

```bash
ps aux | grep '[h]ttpd' | head
```

Если Apache работает от `bitrix`, а папки принадлежат `apache`, Roundcube будет страдать. И вы вместе с ним.

Фикс:

```bash
chown -R bitrix:bitrix /var/www/roundcube
chmod -R 775 /var/www/roundcube/temp /var/www/roundcube/logs /var/www/roundcube/db
systemctl restart httpd
```

## 11. SSL

Сначала DNS:

```dns
mail.example.ru. A 203.0.113.10
```

Проверка:

```bash
dig +short mail.example.ru A
```

Выпуск сертификата:

```bash
scripts/10-enable-letsencrypt-mail.sh
```

Или вручную:

```bash
certbot --nginx -d mail.example.ru
```

Проверка IMAPS:

```bash
openssl s_client -connect mail.example.ru:993 -servername mail.example.ru </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

Проверка SMTP:

```bash
openssl s_client -connect mail.example.ru:465 -servername mail.example.ru </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates

openssl s_client -starttls smtp -connect mail.example.ru:587 -servername mail.example.ru </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

## 12. Firewall

```bash
scripts/08-configure-firewall.sh
```

Проверка:

```bash
firewall-cmd --list-all
ss -tulpn | egrep ':25|:465|:587|:993|:143|:80|:443'
```

Нужны порты:

```text
25
465
587
143
993
80
443
```

## 13. DKIM

```bash
scripts/07-configure-opendkim.sh
```

Скрипт создаст ключ и выведет TXT-запись.

В DNS добавляем:

```dns
mail._domainkey.example.ru. TXT "v=DKIM1; k=rsa; p=ВАШ_КЛЮЧ"
```

Если `dig` показывает DKIM двумя строками в кавычках, это нормально. DNS так умеет. Он не сломался, просто ключ длинный.

Проверка:

```bash
dig +short mail._domainkey.example.ru TXT
```

## 14. SPF, DMARC, PTR

SPF:

```dns
example.ru. TXT "v=spf1 mx ip4:203.0.113.10 ~all"
```

Если есть сервис рассылок:

```dns
example.ru. TXT "v=spf1 mx ip4:203.0.113.10 include:spf.service.example ~all"
```

SPF должен быть один. Не два. Не набор для коллекционеров. Один.

DMARC на старте:

```dns
_dmarc.example.ru. TXT "v=DMARC1; p=none; rua=mailto:postmaster@example.ru; ruf=mailto:postmaster@example.ru; fo=1; adkim=s; aspf=s"
```

Не кладите DMARC на корень домена:

```dns
example.ru. TXT "v=DMARC1; ..."
```

Это не туда.

PTR делается у владельца IP:

```text
203.0.113.10 -> mail.example.ru.
```

Проверка:

```bash
dig -x 203.0.113.10 +short
```

Нужно:

```text
mail.example.ru.
```

## 15. Тест отправки

Открываем Roundcube:

```text
https://mail.example.ru
```

Отправляем письмо на внешний ящик.

Лог:

```bash
tail -f /var/log/maillog
```

Норма:

```text
sasl_username=info@example.ru
status=sent
```

В исходнике полученного письма должно быть:

```text
spf=pass
dkim=pass
DKIM-Signature: ... d=example.ru; s=mail;
```

Если Roundcube падает после STARTTLS, проверьте SMTP host:

```php
$config['smtp_host'] = 'tls://mail.example.ru:587';
```

Не `127.0.0.1`, если сертификат выписан на `mail.example.ru`.

## 16. Переключение MX

Только после успешных тестов.

Было:

```dns
example.ru. MX 10 old-mail.example.
```

Стало:

```dns
example.ru. MX 10 mail.example.ru.
```

Проверяем авторитетные DNS:

```bash
dig @ns1.your-dns-provider.example example.ru MX +short
dig @ns2.your-dns-provider.example example.ru MX +short
```

Нужно:

```text
10 mail.example.ru.
```

Warning вида:

```text
recursion requested but not available
```

на авторитетном DNS - это нормально. Смотреть нужно на `ANSWER SECTION`.

## 17. После MX

Смотрим входящие:

```bash
tail -f /var/log/maillog
```

Отправляем тест с внешнего ящика на `info@example.ru`.

Норма:

```text
postfix/smtpd: connect from ...
postfix/virtual: to=<info@example.ru>, relay=virtual, status=sent
```

Через 30-60 минут делаем контрольный sync:

```bash
scripts/05-sync-mailboxes.sh
```

Старого провайдера лучше держать 2-3 дня как страховку. Не потому что мы ему доверяем. А потому что DNS-кеши живут своей жизнью.

## 18. Мини-администрирование ящиков

Список:

```bash
admin/list-mailboxes.sh
```

Создать:

```bash
admin/create-mailbox.sh newuser@example.ru 'StrongPassword123!'
```

Сменить пароль:

```bash
admin/change-password.sh info@example.ru 'NewStrongPassword123!'
```

Отключить ящик без удаления Maildir:

```bash
admin/disable-mailbox.sh olduser@example.ru
```

Размеры:

```bash
admin/quota-report.sh
```

Это не полноценная панель. Это нормальный безопасный минимум.

PostfixAdmin, Mailcow, Modoboa и iRedMail хороши, но это уже отдельный этап. Ставить их поверх живого BitrixVM с боевыми сайтами - занятие для тех, кто считает, что пожарная сигнализация слишком тихая.

## 19. Финальный чек-лист

```bash
scripts/09-check-dns-and-services.sh
```

Ручной чек:

```bash
dig +short mail.example.ru A
dig +short example.ru MX
dig +short example.ru TXT
dig +short mail._domainkey.example.ru TXT
dig +short _dmarc.example.ru TXT
dig -x 203.0.113.10 +short

ss -tulpn | egrep ':25|:465|:587|:993|:143|:80|:443'

systemctl is-active postfix
systemctl is-active dovecot
systemctl is-active opendkim

postqueue -p
```

Нужно:

```text
A mail.example.ru -> IP
MX example.ru -> mail.example.ru
SPF есть
DKIM есть
DMARC есть
PTR -> mail.example.ru
Postfix active
Dovecot active
OpenDKIM active
очередь Postfix пустая
```

После этого можно сказать, что почта переехала.

Но через час все равно зайдите в логи.

Почта - это не сервис. Это отдельная форма воспитания характера.

## 20. Источники

- Postfix Virtual Domain Hosting Howto: https://www.postfix.org/VIRTUAL_README.html
- Postfix virtual mailbox delivery: https://www.postfix.org/virtual.8.html
- Dovecot passwd-file: https://doc.dovecot.org/main/core/config/auth/databases/passwd_file.html
- Roundcube configuration: https://github.com/roundcube/roundcubemail/wiki/Configuration
- imapsync official site: https://imapsync.lamiral.info/
- imapsync folder mapping and regextrans2: https://imapsync.lamiral.info/FAQ.d/FAQ.Folders_Mapping.txt
- OpenDKIM README: https://www.opendkim.org/opendkim-README
- OpenDKIM config manual: https://www.opendkim.org/opendkim.conf.5.html
