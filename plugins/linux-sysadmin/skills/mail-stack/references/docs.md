# Mail Stack Documentation

Per-component documentation links. For deep dives into any single component,
load the corresponding individual skill (postfix, dovecot, opendkim, certbot).

## Postfix

- Official documentation: https://www.postfix.org/documentation.html
- Configuration parameters (postconf): https://www.postfix.org/postconf.5.html
- main.cf reference: https://www.postfix.org/postconf.5.html
- master.cf reference: https://www.postfix.org/master.5.html
- SASL authentication: https://www.postfix.org/SASL_README.html
- TLS support: https://www.postfix.org/TLS_README.html
- Virtual domain hosting: https://www.postfix.org/VIRTUAL_README.html
- Milter integration (DKIM): https://www.postfix.org/MILTER_README.html
- Address rewriting: https://www.postfix.org/ADDRESS_REWRITING_README.html
- Queue management: https://www.postfix.org/QSHAPE_README.html

## Dovecot

- Official documentation: https://doc.dovecot.org/
- Quick configuration: https://doc.dovecot.org/configuration_manual/quick_configuration/
- SSL/TLS configuration: https://doc.dovecot.org/configuration_manual/dovecot_ssl_configuration/
- Authentication: https://doc.dovecot.org/configuration_manual/authentication/
- LMTP server: https://doc.dovecot.org/configuration_manual/protocols/lmtp_server/
- Maildir format: https://doc.dovecot.org/admin_manual/mailbox_formats/maildir/
- Quota plugin: https://doc.dovecot.org/configuration_manual/quota/
- Sieve filtering: https://doc.dovecot.org/configuration_manual/sieve/
- doveadm reference: https://doc.dovecot.org/admin_manual/doveadm/

## OpenDKIM

- Official site: http://www.opendkim.org/
- Configuration reference (opendkim.conf): http://www.opendkim.org/opendkim.conf.5.html
- opendkim-genkey man page: http://www.opendkim.org/opendkim-genkey.8.html
- opendkim-testkey man page: http://www.opendkim.org/opendkim-testkey.8.html
- DKIM RFC 6376: https://www.rfc-editor.org/rfc/rfc6376
- GitHub repository: https://github.com/trusteddomainproject/OpenDKIM

## Certbot / Let's Encrypt

- Certbot documentation: https://eff-certbot.readthedocs.io/
- Certbot CLI reference: https://eff-certbot.readthedocs.io/en/latest/using.html
- Let's Encrypt getting started: https://letsencrypt.org/getting-started/
- Rate limits: https://letsencrypt.org/docs/rate-limits/
- ACME protocol (RFC 8555): https://www.rfc-editor.org/rfc/rfc8555
- Certbot DNS plugins: https://eff-certbot.readthedocs.io/en/latest/using.html#dns-plugins

## DNS / Email Authentication Standards

- SPF (RFC 7208): https://www.rfc-editor.org/rfc/rfc7208
- SPF syntax reference: https://www.open-spf.org/SPF_Record_Syntax/
- DKIM (RFC 6376): https://www.rfc-editor.org/rfc/rfc6376
- DMARC (RFC 7489): https://www.rfc-editor.org/rfc/rfc7489
- DMARC.org implementation guides: https://dmarc.org/resources/deployment-guides/
- MTA-STS (RFC 8461): https://www.rfc-editor.org/rfc/rfc8461
- DANE / TLSA (RFC 7672): https://www.rfc-editor.org/rfc/rfc7672

## Testing and Validation Tools

- MXToolbox (DNS, blacklist, SMTP tests): https://mxtoolbox.com/SuperTool.aspx
- MXToolbox blacklist check: https://mxtoolbox.com/blacklists.aspx
- Mail-tester (deliverability scoring): https://www.mail-tester.com/
- CheckTLS (TLS verification): https://www.checktls.com/
- DKIM validator: https://www.dmarcanalyzer.com/dkim/dkim-check/
- DMARC record checker: https://www.dmarcanalyzer.com/dmarc/dmarc-record-check/
- SPF record checker: https://www.dmarcanalyzer.com/spf/checker/
- Google Postmaster Tools: https://postmaster.google.com/
- Microsoft SNDS (Smart Network Data Services): https://sendersupport.olc.protection.outlook.com/snds/

## Guides and Tutorials

- Postfix + Dovecot + Let's Encrypt (Linode): https://www.linode.com/docs/guides/email-with-postfix-dovecot-and-mysql/
- ISPmail tutorial (workaround.org): https://workaround.org/ispmail/
- ArchWiki Postfix: https://wiki.archlinux.org/title/Postfix
- ArchWiki Dovecot: https://wiki.archlinux.org/title/Dovecot
- ArchWiki OpenDKIM: https://wiki.archlinux.org/title/OpenDKIM
