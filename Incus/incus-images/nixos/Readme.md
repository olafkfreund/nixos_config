To generate a key file to use for RDP security, you need the winpr-makecert utility
shipped with FreeRDP:

       $ winpr-makecert -rdp -silent -n rdp-security

       This will create a rdp-security.key file.

       You  can  generate  a  key  and  certificate file to use with TLS security using a typical
       openssl invocations:

       $ openssl genrsa -out tls.key 2048
       Generating RSA private key, 2048 bit long modulus
       [...]
       $ openssl req -new -key tls.key -out tls.csr
       [...]
       $ openssl x509 -req -days 365 -signkey tls.key -in tls.csr -out tls.crt
       [...]

       You will get the tls.key and tls.crt files to use with the RDP backend.
