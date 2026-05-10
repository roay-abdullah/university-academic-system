-- ==============================================================================
-- Compatible with: Oracle Database 11g (11.2.x)
-- Run in: SQL*Plus or SQL Developer as SYSTEM / DBA user
-- ==============================================================================

-- ==============================================================================
-- STEP 0: CLEAN SLATE — Drop everything in reverse FK order
--         Safe to run even on a fresh install (WHENEVER SQLERROR CONTINUE skips
--         errors for objects that do not exist yet).
-- ==============================================================================
WHENEVER SQLERROR CONTINUE;

DROP TABLE GRADE_AUDIT;
DROP TABLE GRADE;
DROP TABLE ENROLLMENT;
DROP TABLE EXAM;
DROP TABLE SECTION;
DROP TABLE APP_USERS;
DROP TABLE STUDENT;
DROP TABLE COURSE_PREREQUISITE;
DROP TABLE COURSE;
DROP TABLE TERM;
DROP TABLE PROGRAM;
DROP TABLE INSTRUCTOR;
DROP TABLE DEPARTMENT;

DROP SEQUENCE enrollment_seq;
DROP SEQUENCE grade_seq;
DROP SEQUENCE grade_audit_seq;
DROP SEQUENCE user_seq;

WHENEVER SQLERROR EXIT SQL.SQLCODE;  -- Strict mode back on

-- ==============================================================================
-- STEP 1: SEQUENCES  (Oracle 11g does NOT support IDENTITY columns;
--          sequences + BEFORE INSERT triggers do the same job)
-- ==============================================================================

CREATE SEQUENCE enrollment_seq  START WITH 1  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE grade_seq       START WITH 1  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE grade_audit_seq START WITH 1  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE user_seq        START WITH 1  INCREMENT BY 1 NOCACHE NOCYCLE;

-- ==============================================================================
-- STEP 2: TABLE CREATION (DDL)
-- ==============================================================================

CREATE TABLE DEPARTMENT (
    department_id NUMBER        PRIMARY KEY,
    name          VARCHAR2(100) NOT NULL,
    code          VARCHAR2(10),
    location      VARCHAR2(100)
);

CREATE TABLE INSTRUCTOR (
    instructor_id NUMBER        PRIMARY KEY,
    first_name    VARCHAR2(50)  NOT NULL,
    last_name     VARCHAR2(50)  NOT NULL,
    email         VARCHAR2(100) UNIQUE NOT NULL,
    department_id NUMBER,
    CONSTRAINT fk_inst_dept FOREIGN KEY (department_id) REFERENCES DEPARTMENT(department_id)
);

CREATE TABLE PROGRAM (
    program_id     NUMBER        PRIMARY KEY,
    name           VARCHAR2(100) NOT NULL,
    code           VARCHAR2(10),
    level          VARCHAR2(20),
    total_credits  NUMBER,
    department_id  NUMBER,
    CONSTRAINT fk_prog_dept FOREIGN KEY (department_id) REFERENCES DEPARTMENT(department_id)
);

CREATE TABLE COURSE (
    course_id     NUMBER        PRIMARY KEY,
    code          VARCHAR2(10)  NOT NULL,
    title         VARCHAR2(100) NOT NULL,
    credits       NUMBER,
    description   VARCHAR2(500),
    department_id NUMBER,
    CONSTRAINT fk_course_dept FOREIGN KEY (department_id) REFERENCES DEPARTMENT(department_id)
);

CREATE TABLE COURSE_PREREQUISITE (
    course_id              NUMBER,
    prerequisite_course_id NUMBER,
    CONSTRAINT pk_prereq PRIMARY KEY (course_id, prerequisite_course_id),
    CONSTRAINT fk_prereq_course FOREIGN KEY (course_id)              REFERENCES COURSE(course_id),
    CONSTRAINT fk_prereq_pre    FOREIGN KEY (prerequisite_course_id) REFERENCES COURSE(course_id)
);

CREATE TABLE TERM (
    term_id    NUMBER       PRIMARY KEY,
    name       VARCHAR2(50) NOT NULL,
    start_date DATE,
    end_date   DATE
);

CREATE TABLE SECTION (
    section_id     NUMBER       PRIMARY KEY,
    course_id      NUMBER,
    term_id        NUMBER,
    section_number VARCHAR2(10),
    room           VARCHAR2(50),
    capacity       NUMBER       DEFAULT 50,
    instructor_id  NUMBER,
    CONSTRAINT fk_sec_course FOREIGN KEY (course_id)     REFERENCES COURSE(course_id),
    CONSTRAINT fk_sec_term   FOREIGN KEY (term_id)       REFERENCES TERM(term_id),
    CONSTRAINT fk_sec_inst   FOREIGN KEY (instructor_id) REFERENCES INSTRUCTOR(instructor_id)
);

CREATE TABLE STUDENT (
    student_id    NUMBER        PRIMARY KEY,
    first_name    VARCHAR2(50)  NOT NULL,
    last_name     VARCHAR2(50)  NOT NULL,
    email         VARCHAR2(100) UNIQUE NOT NULL,
    date_of_birth DATE,
    program_id    NUMBER,
    CONSTRAINT fk_stud_prog FOREIGN KEY (program_id) REFERENCES PROGRAM(program_id)
);

-- AUTH TABLE — stores portal login credentials, linked to STUDENT for role=student
CREATE TABLE APP_USERS (
    user_id       NUMBER        PRIMARY KEY,
    username      VARCHAR2(50)  UNIQUE NOT NULL,
    password_hash VARCHAR2(256) NOT NULL,
    role          VARCHAR2(20)  DEFAULT 'student' NOT NULL,
                                -- 'admin' has full access; 'student' sees own data
    student_id    NUMBER,       -- NULL for admin accounts
    created_at    DATE          DEFAULT SYSDATE,
    CONSTRAINT fk_user_student FOREIGN KEY (student_id) REFERENCES STUDENT(student_id),
    CONSTRAINT chk_role CHECK (role IN ('admin', 'student'))
);

-- Trigger: auto-populate APP_USERS.user_id from sequence (11g style)
CREATE OR REPLACE TRIGGER trg_user_id
BEFORE INSERT ON APP_USERS
FOR EACH ROW
BEGIN
    IF :NEW.user_id IS NULL THEN
        SELECT user_seq.NEXTVAL INTO :NEW.user_id FROM DUAL;
    END IF;
END;
/

CREATE TABLE EXAM (
    exam_id    NUMBER       PRIMARY KEY,
    section_id NUMBER,
    type       VARCHAR2(50),
    exam_date  DATE,
    max_score  NUMBER,
    CONSTRAINT fk_exam_sec FOREIGN KEY (section_id) REFERENCES SECTION(section_id)
);

CREATE TABLE ENROLLMENT (
    enrollment_id   NUMBER       PRIMARY KEY,
    student_id      NUMBER,
    section_id      NUMBER,
    enrollment_date DATE         DEFAULT SYSDATE,
    status          VARCHAR2(20) DEFAULT 'Active',
    CONSTRAINT fk_enr_stud FOREIGN KEY (student_id) REFERENCES STUDENT(student_id),
    CONSTRAINT fk_enr_sec  FOREIGN KEY (section_id) REFERENCES SECTION(section_id),
    CONSTRAINT chk_enr_status CHECK (status IN ('Active','Dropped','Completed'))
);

CREATE TABLE GRADE (
    grade_id      NUMBER      PRIMARY KEY,
    enrollment_id NUMBER,
    exam_id       NUMBER,
    score         NUMBER(6,2),
    letter_grade  VARCHAR2(2),
    CONSTRAINT fk_grade_enr  FOREIGN KEY (enrollment_id) REFERENCES ENROLLMENT(enrollment_id),
    CONSTRAINT fk_grade_exam FOREIGN KEY (exam_id)       REFERENCES EXAM(exam_id)
);

-- Audit log for grade changes (11g-compatible: sequence instead of IDENTITY)
CREATE TABLE GRADE_AUDIT (
    audit_id         NUMBER       PRIMARY KEY,
    grade_id         NUMBER,
    enrollment_id    NUMBER,
    exam_id          NUMBER,
    old_score        NUMBER(6,2),
    new_score        NUMBER(6,2),
    old_letter_grade VARCHAR2(2),
    new_letter_grade VARCHAR2(2),
    changed_at       DATE         DEFAULT SYSDATE,
    changed_by       VARCHAR2(50)
);

-- Trigger: auto-populate GRADE_AUDIT.audit_id from sequence
CREATE OR REPLACE TRIGGER trg_grade_audit_id
BEFORE INSERT ON GRADE_AUDIT
FOR EACH ROW
BEGIN
    IF :NEW.audit_id IS NULL THEN
        SELECT grade_audit_seq.NEXTVAL INTO :NEW.audit_id FROM DUAL;
    END IF;
END;
/

-- ==============================================================================
-- STEP 3: SAMPLE DATA (DML)
-- ==============================================================================

-- Departments
INSERT INTO DEPARTMENT VALUES (1, 'Computer Science',    'CS', 'Block A – 3rd Floor');
INSERT INTO DEPARTMENT VALUES (2, 'Software Engineering','SE', 'Block B – 2nd Floor');

-- Instructors
INSERT INTO INSTRUCTOR VALUES (1, 'Ali',    'Khan',   'ali.khan@fast.edu.pk',    1);
INSERT INTO INSTRUCTOR VALUES (2, 'Ayesha', 'Tariq',  'ayesha.tariq@fast.edu.pk',1);
INSERT INTO INSTRUCTOR VALUES (3, 'Bilal',  'Ahmed',  'bilal.ahmed@fast.edu.pk', 2);

-- Programs
INSERT INTO PROGRAM VALUES (1, 'Bachelors in Computer Science',    'BSCS', 'Undergrad', 130, 1);
INSERT INTO PROGRAM VALUES (2, 'Bachelors in Software Engineering','BSSE', 'Undergrad', 128, 2);

-- Courses
INSERT INTO COURSE VALUES (1, 'CS101', 'Intro to Computing',  3, 'Fundamentals of programming and computation', 1);
INSERT INTO COURSE VALUES (2, 'CS201', 'Data Structures',     4, 'Trees, Graphs, Hash Tables',                 1);
INSERT INTO COURSE VALUES (3, 'CS304', 'Database Systems',    4, 'Relational Databases and SQL',               1);
INSERT INTO COURSE VALUES (4, 'SE201', 'Software Engineering',3, 'SDLC, Agile, UML',                           2);

-- Prerequisites
INSERT INTO COURSE_PREREQUISITE VALUES (2, 1); -- DS requires Intro
INSERT INTO COURSE_PREREQUISITE VALUES (3, 2); -- DB requires DS

-- Term
INSERT INTO TERM VALUES (1, 'Fall 2024',
    TO_DATE('2024-08-15','YYYY-MM-DD'),
    TO_DATE('2024-12-15','YYYY-MM-DD'));

-- Sections
INSERT INTO SECTION VALUES (1, 3, 1, 'BCS-4D', 'Room 302', 50, 1);
INSERT INTO SECTION VALUES (2, 1, 1, 'BCS-1A', 'Room 101', 50, 2);
INSERT INTO SECTION VALUES (3, 2, 1, 'BCS-2B', 'Room 205', 40, 3);

-- Students
INSERT INTO STUDENT VALUES (101,'Ahmed','Raza',   'ahmed.r@nu.edu.pk',  TO_DATE('2002-05-14','YYYY-MM-DD'),1);
INSERT INTO STUDENT VALUES (102,'Sara', 'Ali',    'sara.ali@nu.edu.pk',  TO_DATE('2003-08-21','YYYY-MM-DD'),1);
INSERT INTO STUDENT VALUES (103,'Usman','Farooq', 'usman.f@nu.edu.pk',   TO_DATE('2002-11-30','YYYY-MM-DD'),2);

-- Enrollments (use sequence directly in VALUES — valid Oracle 11g syntax)
INSERT INTO ENROLLMENT VALUES (enrollment_seq.NEXTVAL, 101, 1, SYSDATE, 'Active');
INSERT INTO ENROLLMENT VALUES (enrollment_seq.NEXTVAL, 102, 1, SYSDATE, 'Active');
INSERT INTO ENROLLMENT VALUES (enrollment_seq.NEXTVAL, 103, 3, SYSDATE, 'Active');

-- Exams
INSERT INTO EXAM VALUES (1, 1, 'Midterm', TO_DATE('2024-10-15','YYYY-MM-DD'), 100);
INSERT INTO EXAM VALUES (2, 1, 'Final',   TO_DATE('2024-12-10','YYYY-MM-DD'), 100);
INSERT INTO EXAM VALUES (3, 3, 'Midterm', TO_DATE('2024-10-20','YYYY-MM-DD'), 50);

-- Grades
INSERT INTO GRADE VALUES (grade_seq.NEXTVAL, 1, 1, 85, 'B');
INSERT INTO GRADE VALUES (grade_seq.NEXTVAL, 2, 1, 92, 'A');
INSERT INTO GRADE VALUES (grade_seq.NEXTVAL, 3, 3, 38, 'C');

-- ==============================================================================
-- DEFAULT ADMIN ACCOUNT
-- Username: admin  |  Password: Admin@1234
-- Password hash below was generated by Werkzeug (pbkdf2:sha256)
-- You can reset it from the app's Signup page (select role=admin)
-- ==============================================================================
INSERT INTO APP_USERS (user_id, username, password_hash, role, student_id)
VALUES (
    user_seq.NEXTVAL,
    'admin',
    'pbkdf2:sha256:260000$rQVpSMxKJyxLJe2T$e2a4b2b3b2e4c2a4b2b3b2e4c2a4b2b3b2e4c2a4b2b3b2e4c2a4b2b3b2e4c2',
    'admin',
    NULL
);
-- NOTE: The hash above is a placeholder. Run this Python snippet once to get
--       a real hash and UPDATE the row:
--
--   from werkzeug.security import generate_password_hash
--   print(generate_password_hash('Admin@1234'))
--
-- Then: UPDATE APP_USERS SET password_hash='<output>' WHERE username='admin';

COMMIT;

-- ==============================================================================
-- STEP 4: BUSINESS LOGIC TRIGGERS
-- ==============================================================================

-- T1: Prevent enrollment when section is full
CREATE OR REPLACE TRIGGER trg_capacity_check
BEFORE INSERT ON ENROLLMENT
FOR EACH ROW
DECLARE
    v_cap     NUMBER;
    v_current NUMBER;
BEGIN
    SELECT capacity INTO v_cap
    FROM   SECTION WHERE section_id = :NEW.section_id;

    SELECT COUNT(*) INTO v_current
    FROM   ENROLLMENT
    WHERE  section_id = :NEW.section_id AND status = 'Active';

    IF v_current >= v_cap THEN
        RAISE_APPLICATION_ERROR(-20001, 'Section at full capacity. Enrollment rejected.');
    END IF;
END;
/

-- T2: Default enrollment status and date
CREATE OR REPLACE TRIGGER trg_enrollment_defaults
BEFORE INSERT ON ENROLLMENT
FOR EACH ROW
BEGIN
    IF :NEW.status IS NULL THEN
        :NEW.status := 'Active';
    END IF;
    IF :NEW.enrollment_date IS NULL THEN
        :NEW.enrollment_date := SYSDATE;
    END IF;
END;
/

-- T3: Block grade insertion for dropped enrollment
CREATE OR REPLACE TRIGGER trg_no_grade_for_dropped
BEFORE INSERT ON GRADE
FOR EACH ROW
DECLARE
    v_status VARCHAR2(20);
BEGIN
    SELECT status INTO v_status
    FROM   ENROLLMENT WHERE enrollment_id = :NEW.enrollment_id;

    IF v_status = 'Dropped' THEN
        RAISE_APPLICATION_ERROR(-20004, 'Cannot assign grade to a dropped enrollment.');
    END IF;
END;
/

-- T4: Audit trail on grade update
CREATE OR REPLACE TRIGGER trg_grade_audit
AFTER UPDATE ON GRADE
FOR EACH ROW
BEGIN
    INSERT INTO GRADE_AUDIT (
        grade_id, enrollment_id, exam_id,
        old_score, new_score,
        old_letter_grade, new_letter_grade,
        changed_at, changed_by
    ) VALUES (
        :OLD.grade_id, :OLD.enrollment_id, :OLD.exam_id,
        :OLD.score,    :NEW.score,
        :OLD.letter_grade, :NEW.letter_grade,
        SYSDATE, SYS_CONTEXT('USERENV','SESSION_USER')
    );
END;
/

-- ==============================================================================
-- STEP 5: STORED PROCEDURES
-- ==============================================================================

-- SP1: Enroll a student (checks duplicates, prerequisites, capacity via trigger)
CREATE OR REPLACE PROCEDURE enroll_student (
    p_student_id IN NUMBER,
    p_section_id IN NUMBER
) AS
    v_dup    NUMBER;
    v_prereq NUMBER;
    v_course NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_dup
    FROM   ENROLLMENT
    WHERE  student_id = p_student_id AND section_id = p_section_id;
    IF v_dup > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Student is already enrolled in this section.');
    END IF;

    SELECT course_id INTO v_course
    FROM   SECTION WHERE section_id = p_section_id;

    SELECT COUNT(*) INTO v_prereq
    FROM   COURSE_PREREQUISITE cp
    WHERE  cp.course_id = v_course
    AND    cp.prerequisite_course_id NOT IN (
        SELECT sec.course_id
        FROM   ENROLLMENT e
        JOIN   SECTION sec ON e.section_id = sec.section_id
        JOIN   GRADE g     ON e.enrollment_id = g.enrollment_id
        WHERE  e.student_id = p_student_id
        AND    g.letter_grade NOT IN ('F','W')
    );
    IF v_prereq > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'One or more prerequisites are not satisfied.');
    END IF;

    INSERT INTO ENROLLMENT (enrollment_id, student_id, section_id, enrollment_date, status)
    VALUES (enrollment_seq.NEXTVAL, p_student_id, p_section_id, SYSDATE, 'Active');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Enrollment successful for student ' || p_student_id);
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; RAISE;
END enroll_student;
/

-- SP2: Drop enrollment
CREATE OR REPLACE PROCEDURE drop_enrollment (
    p_student_id IN NUMBER,
    p_section_id IN NUMBER
) AS
    v_enroll_id NUMBER;
    v_status    VARCHAR2(20);
BEGIN
    SELECT enrollment_id, status
    INTO   v_enroll_id, v_status
    FROM   ENROLLMENT
    WHERE  student_id = p_student_id AND section_id = p_section_id;

    IF v_status = 'Dropped' THEN
        RAISE_APPLICATION_ERROR(-20005, 'Enrollment is already marked as Dropped.');
    END IF;

    UPDATE ENROLLMENT SET status = 'Dropped' WHERE enrollment_id = v_enroll_id;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Enrollment ' || v_enroll_id || ' dropped.');
EXCEPTION
    WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20006, 'Enrollment record not found.');
    WHEN OTHERS THEN ROLLBACK; RAISE;
END drop_enrollment;
/

-- SP3: Assign grade and auto-compute letter grade
CREATE OR REPLACE PROCEDURE assign_letter_grade (
    p_enrollment_id IN NUMBER,
    p_exam_id       IN NUMBER,
    p_score         IN NUMBER
) AS
    v_max    NUMBER;
    v_pct    NUMBER;
    v_letter VARCHAR2(2);
BEGIN
    SELECT max_score INTO v_max
    FROM   EXAM WHERE exam_id = p_exam_id;

    v_pct    := (p_score / v_max) * 100;
    v_letter := CASE
        WHEN v_pct >= 90 THEN 'A'
        WHEN v_pct >= 80 THEN 'B'
        WHEN v_pct >= 70 THEN 'C'
        WHEN v_pct >= 60 THEN 'D'
        ELSE 'F'
    END;

    INSERT INTO GRADE (grade_id, enrollment_id, exam_id, score, letter_grade)
    VALUES (grade_seq.NEXTVAL, p_enrollment_id, p_exam_id, p_score, v_letter);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Grade recorded: ' || v_letter || ' (' || v_pct || '%)');
EXCEPTION
    WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20007, 'Exam not found.');
    WHEN OTHERS THEN ROLLBACK; RAISE;
END assign_letter_grade;
/

-- SP4: Transfer student to a different program
CREATE OR REPLACE PROCEDURE transfer_student (
    p_student_id     IN NUMBER,
    p_new_program_id IN NUMBER
) AS
    v_old_prog NUMBER;
    v_exists   NUMBER;
BEGIN
    SELECT program_id INTO v_old_prog
    FROM   STUDENT WHERE student_id = p_student_id;

    SELECT COUNT(*) INTO v_exists
    FROM   PROGRAM WHERE program_id = p_new_program_id;
    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20008, 'Target program does not exist.');
    END IF;
    IF v_old_prog = p_new_program_id THEN
        RAISE_APPLICATION_ERROR(-20009, 'Student is already enrolled in this program.');
    END IF;

    UPDATE STUDENT SET program_id = p_new_program_id WHERE student_id = p_student_id;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Student ' || p_student_id || ' transferred: ' || v_old_prog || ' → ' || p_new_program_id);
EXCEPTION
    WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20010, 'Student not found.');
    WHEN OTHERS THEN ROLLBACK; RAISE;
END transfer_student;
/

-- ==============================================================================
-- STEP 6: VIEWS
-- ==============================================================================

CREATE OR REPLACE VIEW student_grade_summary AS
SELECT st.student_id,
       st.first_name || ' ' || st.last_name AS full_name,
       c.title                              AS course,
       t.name                               AS term,
       ROUND(AVG(g.score), 2)               AS avg_score,
       MAX(g.letter_grade)                  AS best_grade
FROM   STUDENT     st
JOIN   ENROLLMENT  e   ON st.student_id    = e.student_id
JOIN   SECTION     sec ON e.section_id     = sec.section_id
JOIN   COURSE      c   ON sec.course_id    = c.course_id
JOIN   TERM        t   ON sec.term_id      = t.term_id
JOIN   GRADE       g   ON e.enrollment_id  = g.enrollment_id
GROUP BY st.student_id, st.first_name, st.last_name, c.title, t.name;

CREATE OR REPLACE VIEW instructor_workload AS
SELECT i.instructor_id,
       i.first_name || ' ' || i.last_name AS instructor,
       t.name                             AS term,
       COUNT(sec.section_id)             AS sections_taught,
       SUM(sec.capacity)                 AS total_seats
FROM   INSTRUCTOR i
JOIN   SECTION    sec ON i.instructor_id = sec.instructor_id
JOIN   TERM       t   ON sec.term_id     = t.term_id
GROUP BY i.instructor_id, i.first_name, i.last_name, t.name;

CREATE OR REPLACE VIEW at_risk_students AS
SELECT st.student_id,
       st.first_name || ' ' || st.last_name AS student,
       st.email,
       p.name                               AS program,
       c.title                              AS course,
       sec.section_number,
       e.status,
       g.score,
       g.letter_grade
FROM   STUDENT     st
JOIN   PROGRAM     p   ON st.program_id   = p.program_id
JOIN   ENROLLMENT  e   ON st.student_id   = e.student_id
JOIN   SECTION     sec ON e.section_id    = sec.section_id
JOIN   COURSE      c   ON sec.course_id   = c.course_id
LEFT JOIN GRADE    g   ON e.enrollment_id = g.enrollment_id
WHERE  e.status = 'Dropped'
OR     g.letter_grade IN ('F','D');

CREATE OR REPLACE VIEW prerequisite_map AS
SELECT c.code  AS course_code,
       c.title AS course_title,
       p.code  AS requires_code,
       p.title AS requires_title,
       p.credits AS prereq_credits
FROM   COURSE_PREREQUISITE cp
JOIN   COURSE c ON cp.course_id              = c.course_id
JOIN   COURSE p ON cp.prerequisite_course_id = p.course_id
ORDER  BY c.code;

-- ==============================================================================
-- STEP 7: QUICK VERIFICATION QUERIES
-- ==============================================================================
SELECT 'DEPARTMENT'  AS tbl, COUNT(*) AS rows FROM DEPARTMENT   UNION ALL
SELECT 'INSTRUCTOR',          COUNT(*) FROM INSTRUCTOR           UNION ALL
SELECT 'PROGRAM',             COUNT(*) FROM PROGRAM              UNION ALL
SELECT 'COURSE',              COUNT(*) FROM COURSE               UNION ALL
SELECT 'TERM',                COUNT(*) FROM TERM                 UNION ALL
SELECT 'SECTION',             COUNT(*) FROM SECTION              UNION ALL
SELECT 'STUDENT',             COUNT(*) FROM STUDENT              UNION ALL
SELECT 'ENROLLMENT',          COUNT(*) FROM ENROLLMENT           UNION ALL
SELECT 'EXAM',                COUNT(*) FROM EXAM                 UNION ALL
SELECT 'GRADE',               COUNT(*) FROM GRADE                UNION ALL
SELECT 'APP_USERS',           COUNT(*) FROM APP_USERS;

-- ==============================================================================
-- END OF SCRIPT
-- ==============================================================================
