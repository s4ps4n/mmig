# DNS records example

Подставьте свой домен и IP.

```dns
mail.example.ru. A 203.0.113.10
example.ru. MX 10 mail.example.ru.
example.ru. TXT "v=spf1 mx ip4:203.0.113.10 ~all"
mail._domainkey.example.ru. TXT "v=DKIM1; k=rsa; p=YOUR_LONG_PUBLIC_KEY"
_dmarc.example.ru. TXT "v=DMARC1; p=none; rua=mailto:postmaster@example.ru; ruf=mailto:postmaster@example.ru; fo=1; adkim=s; aspf=s"
```

PTR делается у владельца IP:

```text
203.0.113.10 -> mail.example.ru.
```

Проверка:

```bash
dig +short mail.example.ru A
dig +short example.ru MX
dig +short example.ru TXT
dig +short mail._domainkey.example.ru TXT
dig +short _dmarc.example.ru TXT
dig -x 203.0.113.10 +short
```
