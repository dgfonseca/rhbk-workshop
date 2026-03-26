# keycloak-ldap

## Getting started

Repository to configure a local LDAP and a local Keycloak to test **User Federation** configuration.

---

### 1) Create a container

Run the following command to create an OpenLDAP container:

```bash
podman run -d \
  --name openldap \
  -p 8389:389 \
  --network ldap-network \
  -e LDAP_ORGANISATION="test.testing.com" \
  -e LDAP_DOMAIN="test.testing.com" \
  -e LDAP_ADMIN_PASSWORD="admin" \
  docker.io/osixia/openldap:latest
```

**Explanation of parameters:**

- `-d` → Runs the container in detached mode (background).
- `--name openldap` → Names the container `openldap`.
- `-p 8389:389` → Maps container port 389 (LDAP default) to host port 8389.
- `--network ldap-network` → Connects the container to the custom `ldap-network` network (must exist or be created).
- `-e LDAP_ORGANISATION` → Sets the organization name inside the LDAP directory.
- `-e LDAP_DOMAIN` → Defines the base domain (`dc=test,dc=testing,dc=com`).
- `-e LDAP_ADMIN_PASSWORD` → Sets the admin password for the LDAP directory.
- `docker.io/osixia/openldap:latest` → Uses the official OpenLDAP image from Docker Hub.

---

### 2) Create the LDIF file

Create a file named `ldap-config.ldif`.


**Explanation of the LDIF structure:**

- The file defines a **directory tree** with organizational units (OU) for users, groups, and service accounts.
- Each `dn` (Distinguished Name) defines a unique entry in the LDAP hierarchy.
- `objectClass: organizationalUnit` → Used to define containers (OUs).
- `objectClass: inetOrgPerson` → Used for users and service accounts.
- `objectClass: groupOfNames` → Used to define groups with member references.
- The hierarchy includes:
  - Users under `OU=Enabled Users`
  - Groups under `OU=Security Groups`
  - A parent group `OCP4_OPENSHIFT_TEST` containing users and a subgroup `OCP4_Prueba`.

---

### 3) Load the LDIF into LDAP

Run the following commands to copy and apply the LDIF file into the container:

```bash
podman cp ldap-config.ldif openldap:/tmp/ocp4_ocp_test.ldif
podman exec -it openldap ldapadd -x -D "cn=admin,dc=test,dc=testing,dc=com" -w admin -f /tmp/ocp4_ocp_test.ldif
```

**Explanation of commands:**

- `podman cp` → Copies the local file `ocp4_ocp_test.ldif` into the container at `/tmp/`.
- `podman exec -it openldap` → Runs a command inside the running `openldap` container interactively.
- `ldapadd` → Adds entries from the LDIF file into the directory.
- `-x` → Uses simple authentication instead of SASL.
- `-D` → Specifies the Bind DN (the LDAP admin user).
- `-w` → Provides the admin password.
- `-f` → Specifies the LDIF file to load.

#### a) Validate the service account

```bash
ldapsearch -x -H ldap://localhost:8389 \
  -D "cn=admin,dc=test,dc=testing,dc=com" -w admin \
  -b "OU=Cuentas de servicio,DC=test,DC=testing,DC=com" \
  "(CN=Cuenta de Servicio Consultas LDAP OP)"
```

**Explanation:**
- `ldapsearch` → Command to query LDAP entries.
- `-x` → Simple authentication.
- `-H ldap://localhost:8389` → Specifies the LDAP server URL.
- `-D` and `-w` → Authenticate as the admin user.
- `-b` → Search base (the distinguished name where the search starts).
- The filter `(CN=Cuenta de Servicio Consultas LDAP OP)` searches specifically for the service account entry.

---

#### b) List enabled users

```bash
ldapsearch -x -H ldap://localhost:8389 \
  -D "cn=admin,dc=test,dc=testing,dc=com" -w admin \
  -b "ou=Enabled Users,ou=User Accounts,dc=test,dc=testing,dc=com"
```

**Explanation:**
- Lists all user entries under the organizational unit `Enabled Users`.
- This command ensures that all test users (`Julio Montero`, `Luis Octavio`, `Hairo Antonio`) were successfully created.

---

#### c) List groups and their members

```bash
ldapsearch -x -H ldap://localhost:8389 \
  -D "cn=admin,dc=test,dc=testing,dc=com" -w admin \
  -b "OU=Groups,DC=test,DC=testing,DC=com" \
  "(objectClass=groupOfNames)" member
```

**Explanation:**
- Searches all entries of type `groupOfNames` under the `Groups` OU.
- Returns each group’s members via the `member` attribute.
- Verifies that:
  - `OCP4_OPENSHIFT_TEST` and `OCP4_Prueba` groups exist.
  - Members are correctly assigned to each group.

---

After completing these steps, your OpenLDAP instance will have:
- Users and service accounts.
- Security groups with nested members.
- A valid structure to integrate with **Keycloak** for **User Federation** testing.

### 4. Run PostgreSQL DB

Before deploying Keycloak, deploy a PostgreSQL container to store Keycloak data.

```bash
podman run -d \
  --name keycloak-db \
  --network ldap-network \
  -e POSTGRES_DB=keycloak \
  -e POSTGRES_USER=developer \
  -e POSTGRES_PASSWORD=Abc12345! \
  -v keycloak_data:/var/lib/postgresql/data \
  docker.io/postgres:16
```

Explanation:
- Creates a container named `keycloak-db` connected to the `ldap-network`.  
- Defines database credentials and name.  
- Mounts a persistent volume `keycloak_data` for PostgreSQL data storage.

---

### 5. Build and Run Keycloak Container

Once the database is running, build and run the **Red Hat Build of Keycloak** container using the provided `Containerfile-psql`.

#### Zip distribution prerequisite (`rhbk-zip.Containerfile`)

If you use `rhbk-zip.Containerfile` instead of `Containerfile-psql`, you must download the **zip distribution** of Red Hat Build of Keycloak from the [Customer Portal — RHBK distributions (version 3.1.0)](https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=rhbk&version=3.1.0&productChanged=yes). Access requires a Red Hat login and appropriate entitlements. After downloading, extract the archive and place the unpacked directory next to the Containerfile using the name expected by `COPY` in `rhbk-zip.Containerfile` (for example `rhbk-26.4.10/`). Then run `podman build -f rhbk-zip.Containerfile .` from this directory.

#### a. Build the Image

```bash
podman build -f ./Containerfile-psql -t test-keycloak
```

**Explanation:**
- `-f ./Containerfile-psql`: Specifies the container file to build the image.  
- `-t test-keycloak`: Tags the resulting image with the name `test-keycloak`.

---

#### b. Run the Container

```bash
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
```

**Explanation:**
- Connects to the same `ldap-network` to communicate with PostgreSQL and LDAP.  
- Exposes HTTP (`8080`), HTTPS (`8443`), and admin console (`9000`) ports.  
- Defines Keycloak database connection parameters and bootstrap admin credentials.

---

### 6. Configure User Federation in Keycloak (step-by-step)

Follow these steps in the Keycloak Admin Console to add an LDAP **User Federation** provider that connects to the local OpenLDAP instance.

1. Open Keycloak Admin Console (e.g. `http://localhost:8080`) and log in with an admin user.

2. In the left menu click **User Federation**.

3. Click **Add provider** and choose **ldap** (LDAP provider).

4. Fill the **Connection** tab fields as follows:

   - **Vendor**: Other  
   - **Connection URL**: `ldap://openldap:389`  
     - This uses the container name `openldap` (must be on same network).
   - **Use Truststore SPI / Use TLS**: leave default (disable) for local testing unless you configured TLS.
   - **Bind DN**: `cn=admin,dc=test,dc=testing,dc=com`  
     - (You provided the admin bind; for production prefer a dedicated service account.)
   - **Bind Credential**: `admin`

5. Configure the **User Federation** settings (same page / next section):

   - **Edit Mode**: `READ_ONLY`  
     - Keycloak will not push profile changes back to LDAP.
   - **Users DN**: `ou=User Accounts,dc=test,dc=testing,dc=com`  
     - The base DN where user entries live.
   - **User Object Classes**: `inetOrgPerson`  
     - Limits discovered entries to LDAP objects of this class.
   - **User LDAP Filter**: `(objectClass=inetOrgPerson)`  
     - Additional LDAP filter (here redundant with object class but explicit).
   - **Search Scope**: `SUBTREE`  
     - Ensures Keycloak searches recursively under the Users DN.
   - **Import Users** (or **Import all users**): `ON` / `TRUE`  
     - Keycloak will import LDAP accounts into its local storage (read-only copies).
   - **Sync Registrations**: `ON` / `TRUE`  
     - New users created in Keycloak will also be created in LDAP (only relevant if edit mode allows write; with `READ_ONLY` it has no effect).
     - Note: With `READ_ONLY`, "Sync Registrations" is typically ineffective — set `WRITABLE` if you want Keycloak to write back to LDAP.

6. (Optional) Tuning fields:

   - **Username LDAP attribute**: `cn`.  
   - **RDN LDAP attribute**: `cn`.  
   - **UUID LDAP attribute**: `cn`.  
   - **Batch size** (for queries / sync): leave default unless you need performance tuning.

7. Save the provider.

8. Test the connection:

   - Click **Test connection** — confirms Keycloak can bind to LDAP using the Bind DN/credential.
   - Click **Test authentication** — ensures the bind DN credentials are valid.

9. Import / synchronize users:

   - After saving, you will see buttons like **Sync all users** (or in the provider actions dropdown).  
   - Click **Synchronize all users** to import all LDAP users into Keycloak (this runs an import job that maps LDAP users to Keycloak users).  
   - Monitor the console messages for success/failure.

10. Verify imported users:

    - Go to **Users** in Keycloak and search for usernames from LDAP (e.g., `Julio Montero`).  
    - Imported users will show a small LDAP icon and the provider as `ldap` (depending on Keycloak version).
11. Configure group mapper(s) (optional but recommended if you want groups):

    - Open the LDAP provider entry and go to **Mappers → Create**.
    - Choose **Mapper Type**: `group-ldap-mapper`
    - Example mapper settings:
      - **Name**: `ldap-groups-mapper`
      - **LDAP Groups DN**: `ou=Security Groups,ou=Groups,dc=test,dc=testing,dc=com`
      - **Group Name LDAP Attribute**: `cn`
      - **Membership LDAP Attribute**: `member`
      - **Group Object Classes**: `groupOfNames`
      - **Preserve Group Inheritance**: ON (if you used nested groups)
      - **Ignore Missing Groups**: ON
    - Save and then use **Sync groups** (or the provider action) to import groups.