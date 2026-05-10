from flask import Flask, jsonify, request, render_template, session
from functools import wraps
from werkzeug.security import generate_password_hash, check_password_hash
import oracledb
import oracledb as cx_Oracle
oracledb.init_oracle_client(lib_dir="/home/roy027/oracle/instantclient_21_19")
import os

app = Flask(__name__)

# Secret key for session encryption — change this in production!
app.secret_key = os.environ.get("SECRET_KEY", "ums-secret-2024-bcs4d")

# ==============================================================================
# DATABASE CONFIGURATION
# ==============================================================================
DB_CONFIG = {
    "user":     "DATABASE1",
    "password": "fast123",
    "dsn":      "localhost:1521/XE"
}

def get_conn():
    return cx_Oracle.connect(**DB_CONFIG)

def rows_to_dicts(cursor):
    cols = [col[0].lower() for col in cursor.description]
    return [dict(zip(cols, row)) for row in cursor.fetchall()]

# ==============================================================================
# AUTH DECORATORS
# ==============================================================================

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            if request.path.startswith("/api/"):
                return jsonify({"error": "Authentication required"}), 401
        return f(*args, **kwargs)
    return decorated

def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if session.get("role") != "admin":
            return jsonify({"error": "Admin access required"}), 403
        return f(*args, **kwargs)
    return decorated

# ==============================================================================
# FRONTEND
# ==============================================================================

@app.route("/")
def index():
    return render_template("dashboard.html")

# ==============================================================================
# AUTH API
# ==============================================================================

@app.route("/api/me")
def me():
    if "user_id" not in session:
        return jsonify({"authenticated": False}), 200
    return jsonify({
        "authenticated": True,
        "user_id":    session["user_id"],
        "username":   session["username"],
        "role":       session["role"],
        "student_id": session.get("student_id")
    })

@app.route("/api/login", methods=["POST"])
def login():
    d = request.json
    if not d or not d.get("username") or not d.get("password"):
        return jsonify({"error": "Username and password are required"}), 400

    conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute(
            "SELECT user_id, password_hash, role, student_id FROM APP_USERS WHERE username = :1",
            (d["username"],)
        )
        row = cur.fetchone()
        if not row or not check_password_hash(row[1], d["password"]):
            return jsonify({"error": "Invalid username or password"}), 401

        user_id, pw_hash, role, student_id = row
        session["user_id"]    = int(user_id)
        session["username"]   = d["username"]
        session["role"]       = role
        session["student_id"] = int(student_id) if student_id else None

        return jsonify({"message": "Login successful", "role": role,
                        "username": d["username"], "student_id": session["student_id"]})
    finally:
        cur.close(); conn.close()

@app.route("/api/signup", methods=["POST"])
def signup():
    d = request.json
    if not d or not d.get("username") or not d.get("password"):
        return jsonify({"error": "Username and password are required"}), 400
    if len(d["password"]) < 6:
        return jsonify({"error": "Password must be at least 6 characters"}), 400

    role       = d.get("role", "student")
    student_id = d.get("student_id")

    conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute("SELECT COUNT(*) FROM APP_USERS WHERE username = :1", (d["username"],))
        if cur.fetchone()[0] > 0:
            return jsonify({"error": "Username already taken"}), 400

        if role == "student" and student_id:
            cur.execute("SELECT COUNT(*) FROM STUDENT WHERE student_id = :1", (int(student_id),))
            if cur.fetchone()[0] == 0:
                return jsonify({"error": "Student ID not found"}), 400

        cur.execute("""
            INSERT INTO APP_USERS (username, password_hash, role, student_id)
            VALUES (:1, :2, :3, :4)
        """, (d["username"], generate_password_hash(d["password"]), role,
              int(student_id) if student_id else None))
        conn.commit()
        return jsonify({"message": "Account created. You may now log in."}), 201
    except cx_Oracle.DatabaseError as e:
        conn.rollback(); return jsonify({"error": str(e)}), 400
    finally:
        cur.close(); conn.close()

@app.route("/api/logout", methods=["POST"])
def logout():
    session.clear()
    return jsonify({"message": "Logged out"})

# ==============================================================================
# STATS
# ==============================================================================

@app.route("/api/stats")
@login_required
def stats():
    conn = get_conn(); cur = conn.cursor(); result = {}
    for key, sql in {
        "students":    "SELECT COUNT(*) FROM STUDENT",
        "courses":     "SELECT COUNT(*) FROM COURSE",
        "instructors": "SELECT COUNT(*) FROM INSTRUCTOR",
        "enrollments": "SELECT COUNT(*) FROM ENROLLMENT WHERE status='Active'"
    }.items():
        cur.execute(sql); result[key] = cur.fetchone()[0]
    cur.close(); conn.close()
    return jsonify(result)

# ==============================================================================
# STUDENTS
# ==============================================================================

@app.route("/api/students", methods=["GET"])
@login_required
def get_students():
    conn = get_conn(); cur = conn.cursor()
    sql = """
        SELECT s.student_id, s.first_name, s.last_name, s.email,
               TO_CHAR(s.date_of_birth,'YYYY-MM-DD') AS date_of_birth, p.name AS program
        FROM   STUDENT s JOIN PROGRAM p ON s.program_id = p.program_id
    """
    if session.get("role") == "student" and session.get("student_id"):
        cur.execute(sql + " WHERE s.student_id=:1 ORDER BY s.student_id", (session["student_id"],))
    else:
        cur.execute(sql + " ORDER BY s.student_id")
    data = rows_to_dicts(cur); cur.close(); conn.close()
    return jsonify(data)

@app.route("/api/students", methods=["POST"])
@login_required
@admin_required
def add_student():
    d = request.json; conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO STUDENT (student_id,first_name,last_name,email,date_of_birth,program_id)
            VALUES (:1,:2,:3,:4,TO_DATE(:5,'YYYY-MM-DD'),:6)
        """, (d["student_id"],d["first_name"],d["last_name"],d["email"],d["date_of_birth"],d["program_id"]))
        conn.commit(); return jsonify({"message": "Student added"}), 201
    except cx_Oracle.DatabaseError as e:
        conn.rollback(); return jsonify({"error": str(e)}), 400
    finally:
        cur.close(); conn.close()

# ==============================================================================
# COURSES / SECTIONS
# ==============================================================================

@app.route("/api/courses")
@login_required
def get_courses():
    conn = get_conn(); cur = conn.cursor()
    cur.execute("""
        SELECT c.course_id,c.code,c.title,c.credits,d.name AS department
        FROM   COURSE c JOIN DEPARTMENT d ON c.department_id=d.department_id ORDER BY c.code
    """)
    data = rows_to_dicts(cur); cur.close(); conn.close(); return jsonify(data)

@app.route("/api/sections")
@login_required
def get_sections():
    conn = get_conn(); cur = conn.cursor()
    cur.execute("""
        SELECT sec.section_id,sec.section_number,sec.room,sec.capacity,
               c.code AS course_code,c.title AS course_title,t.name AS term,
               i.first_name||' '||i.last_name AS instructor,
               sec.capacity-NVL(e.cnt,0) AS seats_left
        FROM   SECTION sec
        JOIN   COURSE c ON sec.course_id=c.course_id
        JOIN   TERM t   ON sec.term_id=t.term_id
        JOIN   INSTRUCTOR i ON sec.instructor_id=i.instructor_id
        LEFT JOIN (SELECT section_id,COUNT(*) cnt FROM ENROLLMENT WHERE status='Active' GROUP BY section_id) e
               ON sec.section_id=e.section_id ORDER BY sec.section_id
    """)
    data = rows_to_dicts(cur); cur.close(); conn.close(); return jsonify(data)

# ==============================================================================
# ENROLLMENTS
# ==============================================================================

@app.route("/api/enrollments/active")
@login_required
def get_active_enrollments():
    conn = get_conn(); cur = conn.cursor()
    sql = """
        SELECT e.enrollment_id, s.first_name||' '||s.last_name AS student,
               c.title AS course, sec.section_number, e.status
        FROM   ENROLLMENT e
        JOIN   STUDENT s  ON e.student_id=s.student_id
        JOIN   SECTION sec ON e.section_id=sec.section_id
        JOIN   COURSE c   ON sec.course_id=c.course_id
        WHERE  e.status='Active'
    """
    if session.get("role") == "student" and session.get("student_id"):
        cur.execute(sql + " AND e.student_id=:1 ORDER BY e.enrollment_id", (session["student_id"],))
    else:
        cur.execute(sql + " ORDER BY e.enrollment_id")
    data = rows_to_dicts(cur); cur.close(); conn.close(); return jsonify(data)

@app.route("/api/enroll", methods=["POST"])
@login_required
@admin_required
def enroll():
    d = request.json; conn = get_conn(); cur = conn.cursor()
    try:
        cur.callproc("enroll_student", [int(d["student_id"]), int(d["section_id"])])
        conn.commit(); return jsonify({"message": "Enrolled"}), 201
    except cx_Oracle.DatabaseError as e:
        conn.rollback(); error_obj,=e.args; return jsonify({"error": error_obj.message}), 400
    finally:
        cur.close(); conn.close()

@app.route("/api/drop", methods=["POST"])
@login_required
@admin_required
def drop():
    d = request.json; conn = get_conn(); cur = conn.cursor()
    try:
        cur.callproc("drop_enrollment", [int(d["student_id"]), int(d["section_id"])])
        conn.commit(); return jsonify({"message": "Dropped"})
    except cx_Oracle.DatabaseError as e:
        conn.rollback(); error_obj,=e.args; return jsonify({"error": error_obj.message}), 400
    finally:
        cur.close(); conn.close()

# ==============================================================================
# GRADES
# ==============================================================================

@app.route("/api/grade", methods=["POST"])
@login_required
@admin_required
def assign_grade():
    d = request.json; conn = get_conn(); cur = conn.cursor()
    try:
        cur.callproc("assign_letter_grade",
                     [int(d["enrollment_id"]), int(d["exam_id"]), float(d["score"])])
        conn.commit(); return jsonify({"message": "Grade assigned"}), 201
    except cx_Oracle.DatabaseError as e:
        conn.rollback(); error_obj,=e.args; return jsonify({"error": error_obj.message}), 400
    finally:
        cur.close(); conn.close()

# ==============================================================================
# TRANSFER
# ==============================================================================

@app.route("/api/transfer", methods=["POST"])
@login_required
@admin_required
def transfer():
    d = request.json; conn = get_conn(); cur = conn.cursor()
    try:
        cur.callproc("transfer_student", [int(d["student_id"]), int(d["new_program_id"])])
        conn.commit(); return jsonify({"message": "Transferred"})
    except cx_Oracle.DatabaseError as e:
        conn.rollback(); error_obj,=e.args; return jsonify({"error": error_obj.message}), 400
    finally:
        cur.close(); conn.close()

# ==============================================================================
# VIEWS
# ==============================================================================

@app.route("/api/views/student_grades")
@login_required
def view_student_grades():
    conn = get_conn(); cur = conn.cursor()
    sql = "SELECT * FROM student_grade_summary"
    if session.get("role") == "student" and session.get("student_id"):
        cur.execute(sql + " WHERE student_id=:1 ORDER BY student_id", (session["student_id"],))
    else:
        cur.execute(sql + " ORDER BY student_id")
    data = rows_to_dicts(cur); cur.close(); conn.close(); return jsonify(data)

@app.route("/api/views/instructor_workload")
@login_required
@admin_required
def view_instructor_workload():
    conn = get_conn(); cur = conn.cursor()
    cur.execute("SELECT * FROM instructor_workload ORDER BY sections_taught DESC")
    data = rows_to_dicts(cur); cur.close(); conn.close(); return jsonify(data)

@app.route("/api/views/at_risk")
@login_required
@admin_required
def view_at_risk():
    conn = get_conn(); cur = conn.cursor()
    cur.execute("SELECT * FROM at_risk_students")
    data = rows_to_dicts(cur); cur.close(); conn.close(); return jsonify(data)

@app.route("/api/views/prereq_map")
@login_required
def view_prereq_map():
    conn = get_conn(); cur = conn.cursor()
    cur.execute("SELECT * FROM prerequisite_map")
    data = rows_to_dicts(cur); cur.close(); conn.close(); return jsonify(data)

# ==============================================================================
# HELPERS
# ==============================================================================

@app.route("/api/programs")
@login_required
def get_programs():
    conn = get_conn(); cur = conn.cursor()
    cur.execute("SELECT program_id,name,code FROM PROGRAM ORDER BY name")
    data = rows_to_dicts(cur); cur.close(); conn.close(); return jsonify(data)

@app.route("/api/exams")
@login_required
def get_exams():
    conn = get_conn(); cur = conn.cursor()
    cur.execute("""
        SELECT e.exam_id,e.type,TO_CHAR(e.exam_date,'YYYY-MM-DD') AS exam_date,
               e.max_score,c.title AS course,sec.section_number
        FROM   EXAM e JOIN SECTION sec ON e.section_id=sec.section_id
               JOIN COURSE c ON sec.course_id=c.course_id ORDER BY e.exam_date DESC
    """)
    data = rows_to_dicts(cur); cur.close(); conn.close(); return jsonify(data)

# ==============================================================================
# ENTRY POINT
# ==============================================================================

if __name__ == "__main__":
    app.run(debug=True, port=5000)
