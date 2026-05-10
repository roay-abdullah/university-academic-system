# University Management System (UMS)

**A comprehensive, database-driven portal for managing university operations, academic records, and student lifecycles.**

Developed by: **Behzad Khan** and **Roy Abdullah**.

---

## 🚀 Project Overview

The University Management System (UMS) is a full-stack web application designed to streamline administrative tasks such as student registration, course enrollment, and grade management. It features a robust **Oracle 11g** backend integrated with a **Flask (Python)** application layer and a responsive **HTML/CSS/JS** frontend.

### Key Features

* **Role-Based Access Control (RBAC):** Distinct dashboards and permissions for Admins and Students.
* **Automated Enrollment:** Enforces course prerequisites and section capacity limits directly via Oracle triggers and stored procedures.
* **Automated Grading:** Letter grades are automatically computed based on raw scores using PL/SQL logic.
* **Live Academic Reporting:** Built-in views for identifying at-risk students, monitoring instructor workloads, and summarizing grades.
* **Secure Authentication:** Passwords are secured using industrial-standard PBKDF2 hashing via the Werkzeug library.

---

## 🛠️ Technology Stack

* **Database:** Oracle Database 11g Express Edition (XE).
* **Backend:** Python 3.9+ with the Flask framework.
* **Frontend:** HTML5, CSS3 (Playfair Display & DM Sans typography), and Vanilla JavaScript.
* **Driver:** `cx_Oracle` / `oracledb` for high-speed Python-to-Oracle connectivity.

---

## 📂 Repository Structure

* `app.py`: The Flask backend containing all API routes and authentication logic.
* `database.sql` / `ums_oracle11g.sql`: Complete SQL scripts including DDL, sequences, triggers, and stored procedures.
* `INTEGRATION_GUIDE.md`: Step-by-step instructions for environment setup and deployment.
* `requirements.txt`: Python dependencies needed to run the application.
* `templates/`:
* `login.html`: Frontend interface for the sign-in and registration pages.
* `dashboard.html`: The main single-page application (SPA) dashboard for Admins and Students.



---

## ⚙️ Installation & Setup

For detailed instructions, refer to the [INTEGRATION_GUIDE.md](https://www.google.com/search?q=./INTEGRATION_GUIDE.md).

1. **Database Setup:**
* Run `ums_oracle11g.sql` in your Oracle 11g instance to create the schema, triggers, and sample data.


2. **Environment Configuration:**
* Install the Oracle Instant Client.
* Install dependencies: `pip install -r requirements.txt`.


3. **Run the Application:**
* Configure your database credentials in `app.py`.
* Start the server: `python app.py`.
* Access the portal at `http://localhost:5000`.



---

## 📊 Database Logic

The system relies on advanced PL/SQL features to maintain academic integrity:

* **Triggers:** `trg_capacity_check` prevents enrollment in full sections; `trg_grade_audit` maintains a permanent log of all grade changes.
* **Procedures:** `enroll_student` validates prerequisites; `assign_letter_grade` auto-calculates A-F grades.
* **Views:** Provides real-time data for the `at_risk_students` and `instructor_workload` reports.

---

## 👥 Authors

* **Behzad Khan** - 24F-0575
* **Roy Abdullah** - 24F-0570

---

## 📜 License

This project is developed for academic purposes. Please cite the authors if using this schema or logic for other projects.
