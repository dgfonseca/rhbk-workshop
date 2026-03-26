###Configure local LDAP
podman run -d   --name openldap   -p 8389:389 --network ldap-network -e LDAP_ORGANISATION="test.testing.com"   -e LDAP_DOMAIN="test.testing.com"   -e LDAP_ADMIN_PASSWORD="admin"   docker.io/osixia/openldap:latest
podman cp ocp4_ocp_test.ldif openldap:/tmp/ocp4_ocp_test.ldif
podman exec -it openldap ldapadd -x -D "cn=admin,dc=test,dc=testing,dc=com" -w admin -f /tmp/ocp4_ocp_test.ldif

###Valudate LDAP Configuration
ldapsearch -x -H ldap://localhost:8389   -D "cn=admin,dc=test,dc=testing,dc=com" -w admin   -b "OU=Cuentas de servicio,DC=test,DC=testing,DC=com"   "(CN=Cuenta de Servicio Consultas LDAP OP)"
ldapwhoami -x -H ldap://localhost:8389   -D "CN=Cuenta de Servicio Consultas LDAP OP,OU=Cuentas de servicio,DC=test,DC=testing,DC=com"   -w test
ldapsearch -x \
  -H ldap://localhost:8389 \
  -D "CN=Cuenta de Servicio Consultas LDAP OP,OU=Cuentas de servicio,DC=test,DC=testing,DC=com" \
  -W \
  -b "OU=User Accounts,DC=test,DC=testing,DC=com" \
  "(&(objectclass=person)(memberOf=CN=OCP4_OPENSHIFT_TEST,OU=Security Groups,OU=Groups,DC=test,DC=testing,DC=com))" \
  objectGUID

### Run Postgresql DB
podman run -d \
  --name keycloak-db \
  --network ldap-network \
  -e POSTGRES_DB=keycloak \
  -e POSTGRES_USER=developer \
  -e POSTGRES_PASSWORD=Abc12345! \
  -v keycloak_data:/var/lib/postgresql/data \
  docker.io/postgres:16

### Build and run custom Keycloak Image
  podman build -f ./rhbk-zip.Containerfile -t test-keycloak

  podman run -d \
  --name keycloak-psql \
  --network ldap-network \
  -p 8080:8080 -p 8443:8443 -p 9000:9000 \
  -e KC_DB=postgres \
  -e KC_DB_URL="jdbc:postgresql://keycloak-db:5432/keycloak" \
  -e KC_DB_USERNAME=developer \
  -e KC_DB_PASSWORD=Abc12345! \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=change_me \
  test-keycloak


### Validate LDAP Configuration
  ldapsearch -x   -H ldap://localhost:8389 -D "CN=Cuenta de Servicio Consultas LDAP OP,OU=Cuentas de servicio,DC=test,DC=testing,DC=com" -W
  ldapwhoami -x -H ldap://localhost:8389   -D "CN=Cuenta de Servicio Consultas LDAP OP,OU=Cuentas de servicio,DC=test,DC=testing,DC=com" -W


  ldapsearch -x -H ldap://localhost:8389   -D "cn=Cuenta de Servicio Consultas LDAP OP,ou=Cuentas de servicio,dc=test,dc=testing,dc=com"   -w test123   -b "OU=User Accounts,DC=test,DC=testing,DC=com" "(objectClass=person)" cn

  ldapsearch -x -H ldap://localhost:8389   -D "cn=admin,dc=test,dc=testing,dc=com" -w admin -b "ou=Enabled Users,ou=User Accounts,dc=test,dc=testing,dc=com"

  ldapsearch -x -H ldap://localhost:8389   -D "cn=Cuenta de Servicio Consultas LDAP OP,ou=Cuentas de servicio,dc=test,dc=testing,dc=com"   -w test123 -b "CN=OCP4_Prueba,OU=Security Groups,OU=Groups,DC=test,DC=testing,DC=com" "(objectClass=groupOfNames)" member
  
  ldapsearch -x -H ldap://localhost:8389   -D "cn=admin,dc=test,dc=testing,dc=com" -w admin -b "OU=Groups,DC=test,DC=testing,DC=com" "(objectClass=groupOfNames)" member

  ldapsearch -x -H ldap://localhost:8389   -D "cn=Cuenta de Servicio Consultas LDAP OP,ou=Cuentas de servicio,dc=test,dc=testing,dc=com"   -w test123 -b "OU=Groups,DC=test,DC=testing,DC=com" "(objectClass=groupOfNames)" member