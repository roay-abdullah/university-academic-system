# UMS — Step-by-Step Integration Guide
## Roll No: 24F-0575, 24F-0570 | BCS-4D | Database Systems

---

## WHAT YOU NEED BEFORE STARTING

| Tool | Where to get it |
|------|----------------|
| Oracle Database 11g XE | Already installed on your lab PC |
| SQL Developer 4.x | Already installed, or download from oracle.com |
| Python 3.9+ | python.org |
| Oracle Instant Client 11.2 | oracle.com/database/technologies/instant-client |
| pip (comes with Python) | — |

---

## STEP 1 — Verify Oracle 11g is Running

Open **Command Prompt** and run:

```
sqlplus system/oracle@localhost:1521/XE
```

If you see `SQL>`, Oracle is running. Type `exit` to quit.

If connection fails, start Oracle:
- Open **Services** (Windows+R → `services.msc`)
- Find **OracleServiceXE** and **OracleXETNSListener** → right-click → Start

---

## STEP 2 — Run the SQL Script in SQL Developer

1. Open **SQL Developer**
2. Connect using:
   - Username: `system`
   - Password: `oracle` (or whatever you set during install)
   - Hostname: `localhost`
   - Port: `1521`
   - SID: `XE`
3. Click **File → Open** → select `ums_oracle11g.sql`
4. Press **F5** (Run Script) — this runs the ENTIRE file at once
5. Check the Script Output panel at the bottom — you should see:
   ```
   Table DEPARTMENT created.
   Table INSTRUCTOR created.
   ...
   Trigger TRG_USER_ID compiled.
   Procedure ENROLL_STUDENT compiled.
   ...
   ```
6. At the end, the verification query will show row counts like:
   ```
   DEPARTMENT   2
   INSTRUCTOR   3
   STUDENT      3
   APP_USERS    1
   ...
   ```

**If any errors appear:** Most common issue is running the script twice without the DROP statements
working. Select all (Ctrl+A) and run again — the `WHENEVER SQLERROR CONTINUE` block handles drops.

---

## STEP 3 — Fix the Admin Password

The SQL file inserts a **placeholder** password hash for the admin account.
You must replace it with a real Werkzeug hash.

### Option A: Use Python (recommended)

Open Command Prompt and run:

```python
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('Admin@1234'))"
```

Copy the output (it looks like `pbkdf2:sha256:260000$abc123...`).

Then in SQL Developer, run:

```sql
UPDATE APP_USERS
SET password_hash = 'PASTE_YOUR_HASH_HERE'
WHERE username = 'admin';

COMMIT;
```

### Option B: Create a fresh admin via the Signup form

After the app is running (Step 6), go to the Signup tab:
- Username: `admin2`
- Role: `Admin`
- Password: anything you like
- No Student ID needed for admin

---

## STEP 4 — Install Oracle Instant Client

cx_Oracle needs the Oracle Instant Client DLLs to connect to Oracle 11g.

1. Download **Oracle Instant Client 11.2 Basic** for Windows (32-bit or 64-bit — must match your Python):
   - https://www.oracle.com/database/technologies/instant-client/winx64-64-downloads.html
2. Extract to a folder, e.g. `C:\oracle\instantclient_11_2`
3. Add that folder to your **PATH**:
   - Windows Search → "Environment Variables"
   - Under "System Variables" → select **Path** → Edit → New
   - Add: `C:\oracle\instantclient_11_2`
   - Click OK on all dialogs
4. **Restart** Command Prompt for the PATH change to take effect

---

## STEP 5 — Install Python Dependencies

Open Command Prompt **in your project folder**:

```
cd path\to\ums_project
pip install -r requirements.txt
```

This installs:
- `Flask` — the web framework
- `cx_Oracle` — Oracle database driver for Python

Verify the install:
```
python -c "import cx_Oracle; print(cx_Oracle.version)"
```
You should see `8.3.0` (or similar).

---

## STEP 6 — Configure Database Credentials in app.py

Open `app.py` and find the `DB_CONFIG` block near the top:

```python
DB_CONFIG = {
    "user":     os.environ.get("DB_USER",     "system"),   # <- your Oracle username
    "password": os.environ.get("DB_PASSWORD", "oracle"),   # <- your Oracle password
    "dsn":      cx_Oracle.makedsn(
                    os.environ.get("DB_HOST",    "localhost"),
                    int(os.environ.get("DB_PORT", 1521)),
                    service_name=os.environ.get("DB_SERVICE", "XE")
                )
}
```

**If your credentials match the defaults above, no changes needed.**

If different (e.g., your password is `fast123`), either:
- Edit the defaults directly in `app.py`, OR
- Set environment variables before running:
  ```
  set DB_PASSWORD=fast123
  ```

---

## STEP 7 — Run the Flask Application

In Command Prompt, from your project folder:

```
python app.py
```

Expected output:
```
 * Running on http://127.0.0.1:5000
 * Debug mode: on
```

Open your browser and go to: **http://localhost:5000**

---

## STEP 8 — First Login

You will see the **UMS Login Screen**.

**Login as Admin:**
- Username: `admin`
- Password: `Admin@1234` (after you updated the hash in Step 3)

**Admin role** gives you full access:
- Dashboard with KPI cards
- Students management (add, transfer)
- Enrollments (enroll/drop via stored procedures)
- Grade assignment
- All DB Views

**Login as Student:**
1. First create a student account via the Signup tab
2. Enter a valid Student ID from the STUDENT table (e.g., 101, 102, 103)
3. Choose Role: Student
4. Create a password

**Student role** shows a restricted view:
- Their own enrollments on the dashboard
- Courses and Sections (read-only)
- Their own grades

---

## STEP 9 — Test All Features (Checklist)

Go through these in order to verify everything works:

### Database
- [ ] All tables created (Step 2 verification query shows row counts)
- [ ] Admin account exists in APP_USERS
- [ ] Triggers compiled (no red X in SQL Developer)
- [ ] Stored procedures compiled

### Auth
- [ ] Admin login works
- [ ] Student signup with existing Student ID works
- [ ] Wrong password shows error message
- [ ] Logout clears session (Back button doesn't re-enter without login)

### Data Operations
- [ ] Dashboard KPI cards load numbers
- [ ] Students table loads
- [ ] Add Student form inserts to STUDENT table
- [ ] Enroll → calls `enroll_student` stored procedure
- [ ] Drop → calls `drop_enrollment` stored procedure
- [ ] Assign Grade → calls `assign_letter_grade` stored procedure, letter grade auto-computed
- [ ] Transfer → calls `transfer_student` stored procedure
- [ ] DB Views page loads all four Oracle views

---

## STEP 10 — Project Folder Structure

Your final submission should look like this:

```
UMS_Project/
├── app.py                    ← Flask backend (all routes + auth)
├── requirements.txt          ← pip dependencies
├── ums_oracle11g.sql         ← Complete Oracle 11g database script
└── templates/
    └── dashboard.html        ← Single-page frontend (login + app)
```

---

## COMMON ERRORS & FIXES

| Error | Cause | Fix |
|-------|-------|-----|
| `DPI-1047: Cannot locate a 64-bit Oracle Client library` | Instant Client not in PATH | Re-do Step 4, restart CMD |
| `ORA-12541: TNS:no listener` | Oracle listener not running | Start OracleXETNSListener service |
| `ORA-01017: invalid username/password` | Wrong credentials | Update DB_CONFIG in app.py |
| `ORA-00942: table or view does not exist` | SQL script not run yet | Run ums_oracle11g.sql (Step 2) |
| `ModuleNotFoundError: No module named 'cx_Oracle'` | pip install not done | Re-do Step 5 |
| `Authentication required` (401 in browser) | Session expired | Log in again |
| Admin login says "Invalid password" | Placeholder hash still in DB | Do Step 3 |

---

## NOTES FOR THE VIVA

Things you should be able to explain:

1. **Why sequences instead of IDENTITY columns?**
   Oracle 11g doesn't support IDENTITY (that's Oracle 12c+). We use `CREATE SEQUENCE` + a `BEFORE INSERT` trigger to auto-generate primary keys.

2. **How does role-based access work?**
   Flask `session` stores the user's role after login. Python decorators (`@login_required`, `@admin_required`) check the session before each API route runs. The frontend also hides admin-only UI elements by toggling CSS classes.

3. **How does enroll_student work end-to-end?**
   Frontend → `POST /api/enroll` → Flask calls `cur.callproc("enroll_student", [...])` → Oracle stored procedure checks duplicates, prerequisites, capacity (via trigger), then inserts into ENROLLMENT.

4. **What does the grade audit trigger do?**
   `trg_grade_audit` fires AFTER UPDATE on GRADE and writes the old/new values + timestamp + database user into GRADE_AUDIT. This creates a permanent change log.

5. **What is the at_risk_students view?**
   It's a saved query (Oracle VIEW) that joins STUDENT, ENROLLMENT, SECTION, COURSE, and GRADE to surface any student who is either Dropped or has a failing/D grade.
