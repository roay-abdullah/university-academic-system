-- =============================================================================
-- Compatible: Oracle 11g XE / Standard / Enterprise
-- Run this script as SYSTEM or as your schema user.
-- =============================================================================

-- =============================================================================
-- SECTION 0: SAFE CLEANUP (Drop in reverse FK order)
-- =============================================================================
BEGIN EXECUTE IMMEDIATE 'DROP TABLE GRADE_AUDIT';      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE GRADE';             EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ENROLLMENT';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE EXAM';              EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE SECTION';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE STUDENT';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE USERS';             EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE TERM';              EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE COURSE_PREREQUISITE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE COURSE';            EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE PROGRAM';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE INSTRUCTOR';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE DEPARTMENT';        EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Drop all sequences
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE department_seq';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE instructor_seq';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE program_seq';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE course_seq';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE term_seq';          EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE section_seq';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE student_seq';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE exam_seq';          EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE enrollment_seq';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE grade_seq';         EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE grade_audit_seq';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE users_seq';         EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- =============================================================================
-- SECTION 1: SEQUENCES
-- =============================================================================

CREATE SEQUENCE department_seq   START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE instructor_seq   START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE program_seq      START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE course_seq       START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE term_seq         START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE section_seq      START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE student_seq      START WITH 101 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE exam_seq         START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE enrollment_seq   START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE grade_seq        START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE grade_audit_seq  START WITH 1  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE users_seq        START WITH 1  INCREMENT BY 1 NOCACHE;

-- =============================================================================
-- SECTION 2: TABLE CREATION (DDL)
-- Notes:
--   • VARCHAR2 used (Oracle native; Oracle maps VARCHAR → VARCHAR2 internally)
--   • NUMBER used (Oracle native; INT maps to NUMBER(38))
--   • CLOB used for long text (TEXT is not a native Oracle type)
--   • DATE used (Oracle DATE stores both date + time)
--   • No GENERATED AS IDENTITY (Oracle 12c+ feature); sequences used instead
-- =============================================================================

CREATE TABLE DEPARTMENT (
    department_id   NUMBER          PRIMARY KEY,
    name            VARCHAR2(100)   NOT NULL,
    code            VARCHAR2(10)    NOT NULL UNIQUE,
    location        VARCHAR2(100)
);

CREATE TABLE INSTRUCTOR (
    instructor_id   NUMBER          PRIMARY KEY,
    first_name      VARCHAR2(50)    NOT NULL,
    last_name       VARCHAR2(50)    NOT NULL,
    email           VARCHAR2(100)   UNIQUE,
    department_id   NUMBER,
    CONSTRAINT fk_instr_dept FOREIGN KEY (department_id)
        REFERENCES DEPARTMENT(department_id)
);

CREATE TABLE PROGRAM (
    program_id      NUMBER          PRIMARY KEY,
    name            VARCHAR2(100)   NOT NULL,
    code            VARCHAR2(10)    NOT NULL UNIQUE,
    level           VARCHAR2(20),
    total_credits   NUMBER,
    department_id   NUMBER,
    CONSTRAINT fk_prog_dept FOREIGN KEY (department_id)
        REFERENCES DEPARTMENT(department_id)
);

CREATE TABLE COURSE (
    course_id       NUMBER          PRIMARY KEY,
    code            VARCHAR2(10)    NOT NULL UNIQUE,
    title           VARCHAR2(100)   NOT NULL,
    credits         NUMBER          DEFAULT 3,
    description     CLOB,
    department_id   NUMBER,
    CONSTRAINT fk_course_dept FOREIGN KEY (department_id)
        REFERENCES DEPARTMENT(department_id)
);

CREATE TABLE COURSE_PREREQUISITE (
    course_id               NUMBER,
    prerequisite_course_id  NUMBER,
    CONSTRAINT pk_prereq PRIMARY KEY (course_id, prerequisite_course_id),
    CONSTRAINT fk_prereq_course FOREIGN KEY (course_id)
        REFERENCES COURSE(course_id),
    CONSTRAINT fk_prereq_pre FOREIGN KEY (prerequisite_course_id)
        REFERENCES COURSE(course_id)
);

CREATE TABLE TERM (
    term_id         NUMBER          PRIMARY KEY,
    name            VARCHAR2(50)    NOT NULL,
    start_date      DATE            NOT NULL,
    end_date        DATE            NOT NULL
);

CREATE TABLE SECTION (
    section_id      NUMBER          PRIMARY KEY,
    course_id       NUMBER          NOT NULL,
    term_id         NUMBER          NOT NULL,
    section_number  VARCHAR2(10)    NOT NULL,
    room            VARCHAR2(50),
    capacity        NUMBER          DEFAULT 40,
    instructor_id   NUMBER,
    CONSTRAINT fk_sec_course  FOREIGN KEY (course_id)    REFERENCES COURSE(course_id),
    CONSTRAINT fk_sec_term    FOREIGN KEY (term_id)      REFERENCES TERM(term_id),
    CONSTRAINT fk_sec_instr   FOREIGN KEY (instructor_id) REFERENCES INSTRUCTOR(instructor_id)
);

CREATE TABLE STUDENT (
    student_id      NUMBER          PRIMARY KEY,
    first_name      VARCHAR2(50)    NOT NULL,
    last_name       VARCHAR2(50)    NOT NULL,
    email           VARCHAR2(100)   UNIQUE,
    date_of_birth   DATE,
    program_id      NUMBER,
    CONSTRAINT fk_stu_prog FOREIGN KEY (program_id) REFERENCES PROGRAM(program_id)
);

-- USERS — for login/signup (passwords hashed by Flask/Werkzeug)
CREATE TABLE USERS (
    user_id         NUMBER          PRIMARY KEY,
    username        VARCHAR2(50)    NOT NULL UNIQUE,
    password_hash   VARCHAR2(256)   NOT NULL,
    role            VARCHAR2(20)    DEFAULT 'Student' NOT NULL,
                                    -- Allowed values: 'Admin', 'Student'
    student_id      NUMBER,         -- NULL for Admin users
    created_at      DATE            DEFAULT SYSDATE,
    CONSTRAINT fk_users_stu FOREIGN KEY (student_id) REFERENCES STUDENT(student_id),
    CONSTRAINT chk_users_role CHECK (role IN ('Admin', 'Student'))
);

CREATE TABLE EXAM (
    exam_id         NUMBER          PRIMARY KEY,
    section_id      NUMBER          NOT NULL,
    type            VARCHAR2(50),   -- e.g. 'Midterm', 'Final', 'Quiz'
    exam_date       DATE,
    max_score       NUMBER          DEFAULT 100,
    CONSTRAINT fk_exam_sec FOREIGN KEY (section_id) REFERENCES SECTION(section_id)
);

CREATE TABLE ENROLLMENT (
    enrollment_id   NUMBER          PRIMARY KEY,
    student_id      NUMBER          NOT NULL,
    section_id      NUMBER          NOT NULL,
    enrollment_date DATE            DEFAULT SYSDATE,
    status          VARCHAR2(20)    DEFAULT 'Active',
    CONSTRAINT fk_enroll_stu  FOREIGN KEY (student_id)  REFERENCES STUDENT(student_id),
    CONSTRAINT fk_enroll_sec  FOREIGN KEY (section_id)  REFERENCES SECTION(section_id),
    CONSTRAINT chk_enroll_status CHECK (status IN ('Active','Dropped','Completed'))
);

CREATE TABLE GRADE (
    grade_id        NUMBER          PRIMARY KEY,
    enrollment_id   NUMBER          NOT NULL,
    exam_id         NUMBER          NOT NULL,
    score           NUMBER(6,2),
    letter_grade    VARCHAR2(2),
    CONSTRAINT fk_grade_enroll FOREIGN KEY (enrollment_id) REFERENCES ENROLLMENT(enrollment_id),
    CONSTRAINT fk_grade_exam   FOREIGN KEY (exam_id)       REFERENCES EXAM(exam_id)
);

-- GRADE_AUDIT — auto PK via sequence + trigger (Oracle 11g compatible)
CREATE TABLE GRADE_AUDIT (
    audit_id        NUMBER          PRIMARY KEY,
    grade_id        NUMBER,
    enrollment_id   NUMBER,
    exam_id         NUMBER,
    old_score       NUMBER(6,2),
    new_score       NUMBER(6,2),
    old_letter_grade VARCHAR2(2),
    new_letter_grade VARCHAR2(2),
    changed_at      DATE,
    changed_by      VARCHAR2(50)
);

-- =============================================================================
-- SECTION 3: SAMPLE DATA (DML)
-- =============================================================================

INSERT INTO DEPARTMENT VALUES (department_seq.NEXTVAL, 'Computer Science',       'CS', 'Block A – Room 101');
INSERT INTO DEPARTMENT VALUES (department_seq.NEXTVAL, 'Software Engineering',   'SE', 'Block B – Room 201');
INSERT INTO DEPARTMENT VALUES (department_seq.NEXTVAL, 'Information Technology', 'IT', 'Block C – Room 301');

INSERT INTO INSTRUCTOR VALUES (instructor_seq.NEXTVAL, 'Ali',    'Khan',    'ali.khan@fast.edu.pk',    1);
INSERT INTO INSTRUCTOR VALUES (instructor_seq.NEXTVAL, 'Ayesha', 'Tariq',   'ayesha.tariq@fast.edu.pk',1);
INSERT INTO INSTRUCTOR VALUES (instructor_seq.NEXTVAL, 'Usman',  'Ghani',   'usman.ghani@fast.edu.pk', 2);

INSERT INTO PROGRAM VALUES (program_seq.NEXTVAL, 'Bachelors in Computer Science',       'BSCS', 'Undergrad', 130, 1);
INSERT INTO PROGRAM VALUES (program_seq.NEXTVAL, 'Bachelors in Software Engineering',   'BSSE', 'Undergrad', 128, 2);
INSERT INTO PROGRAM VALUES (program_seq.NEXTVAL, 'Bachelors in Information Technology', 'BSIT', 'Undergrad', 126, 3);

INSERT INTO COURSE VALUES (course_seq.NEXTVAL, 'CS101', 'Intro to Computing',  3, 'Fundamental computing concepts and programming basics.', 1);
INSERT INTO COURSE VALUES (course_seq.NEXTVAL, 'CS201', 'Data Structures',     4, 'Trees, graphs, linked lists, hash tables and their applications.', 1);
INSERT INTO COURSE VALUES (course_seq.NEXTVAL, 'CS304', 'Database Systems',    4, 'Relational databases, SQL, normalization, and transactions.', 1);
INSERT INTO COURSE VALUES (course_seq.NEXTVAL, 'CS401', 'Operating Systems',   3, 'Process management, memory, file systems, and concurrency.', 1);
INSERT INTO COURSE VALUES (course_seq.NEXTVAL, 'SE201', 'Software Engineering',3, 'SDLC, requirements, design patterns, and testing.', 2);

-- Prerequisites
INSERT INTO COURSE_PREREQUISITE VALUES (2, 1);  -- Data Structures requires Intro to Computing
INSERT INTO COURSE_PREREQUISITE VALUES (3, 2);  -- DB Systems requires Data Structures
INSERT INTO COURSE_PREREQUISITE VALUES (4, 2);  -- OS requires Data Structures

INSERT INTO TERM VALUES (term_seq.NEXTVAL, 'Fall 2024',   TO_DATE('2024-08-15','YYYY-MM-DD'), TO_DATE('2024-12-20','YYYY-MM-DD'));
INSERT INTO TERM VALUES (term_seq.NEXTVAL, 'Spring 2025', TO_DATE('2025-01-20','YYYY-MM-DD'), TO_DATE('2025-05-30','YYYY-MM-DD'));

-- Sections
INSERT INTO SECTION VALUES (section_seq.NEXTVAL, 3, 1, 'BCS-4D', 'Room 302', 50, 1);  -- DB Systems, Ali Khan
INSERT INTO SECTION VALUES (section_seq.NEXTVAL, 1, 1, 'BCS-1A', 'Room 101', 50, 2);  -- Intro, Ayesha
INSERT INTO SECTION VALUES (section_seq.NEXTVAL, 2, 1, 'BCS-2B', 'Room 205', 40, 1);  -- DS, Ali Khan
INSERT INTO SECTION VALUES (section_seq.NEXTVAL, 4, 2, 'BCS-4A', 'Room 401', 35, 3);  -- OS, Usman

-- Students (student_seq starts at 101)
INSERT INTO STUDENT VALUES (student_seq.NEXTVAL, 'Ahmed',  'Raza',    'ahmed.r@nu.edu.pk',   TO_DATE('2002-05-14','YYYY-MM-DD'), 1);
INSERT INTO STUDENT VALUES (student_seq.NEXTVAL, 'Sara',   'Ali',     'sara.ali@nu.edu.pk',  TO_DATE('2003-08-21','YYYY-MM-DD'), 1);
INSERT INTO STUDENT VALUES (student_seq.NEXTVAL, 'Bilal',  'Chaudhry','bilal.c@nu.edu.pk',   TO_DATE('2001-12-03','YYYY-MM-DD'), 2);
INSERT INTO STUDENT VALUES (student_seq.NEXTVAL, 'Hira',   'Noor',    'hira.n@nu.edu.pk',    TO_DATE('2003-03-17','YYYY-MM-DD'), 1);

-- NOTE: USERS table will be populated by the seed_admin.py script
-- because passwords are hashed by Python (Werkzeug). See SETUP_GUIDE.md Step 6.

-- Enrollments (students 101–104 are in section 1 and 2)
INSERT INTO ENROLLMENT VALUES (enrollment_seq.NEXTVAL, 101, 1, SYSDATE, 'Active');
INSERT INTO ENROLLMENT VALUES (enrollment_seq.NEXTVAL, 102, 1, SYSDATE, 'Active');
INSERT INTO ENROLLMENT VALUES (enrollment_seq.NEXTVAL, 103, 2, SYSDATE, 'Active');
INSERT INTO ENROLLMENT VALUES (enrollment_seq.NEXTVAL, 104, 1, SYSDATE, 'Active');
INSERT INTO ENROLLMENT VALUES (enrollment_seq.NEXTVAL, 101, 3, SYSDATE, 'Dropped');  -- Dropped enrollment for testing

-- Exams
INSERT INTO EXAM VALUES (exam_seq.NEXTVAL, 1, 'Midterm', TO_DATE('2024-10-15','YYYY-MM-DD'), 100);
INSERT INTO EXAM VALUES (exam_seq.NEXTVAL, 1, 'Final',   TO_DATE('2024-12-10','YYYY-MM-DD'), 100);
INSERT INTO EXAM VALUES (exam_seq.NEXTVAL, 2, 'Midterm', TO_DATE('2024-10-20','YYYY-MM-DD'), 100);

-- Grades
INSERT INTO GRADE VALUES (grade_seq.NEXTVAL, 1, 1, 85, 'B');   -- Ahmed, DB Midterm
INSERT INTO GRADE VALUES (grade_seq.NEXTVAL, 2, 1, 92, 'A');   -- Sara,  DB Midterm
INSERT INTO GRADE VALUES (grade_seq.NEXTVAL, 4, 1, 55, 'F');   -- Hira,  DB Midterm (at-risk)
INSERT INTO GRADE VALUES (grade_seq.NEXTVAL, 3, 3, 78, 'C');   -- Bilal, Intro Midterm

COMMIT;

-- =============================================================================
-- SECTION 4: TRIGGERS
-- =============================================================================

-- T1: Auto-assign GRADE_AUDIT primary key (replaces IDENTITY — Oracle 11g fix)
CREATE OR REPLACE TRIGGER trg_grade_audit_pk
BEFORE INSERT ON GRADE_AUDIT
FOR EACH ROW
BEGIN
    :NEW.audit_id := grade_audit_seq.NEXTVAL;
END;
/

-- T2: Capacity check before enrollment
CREATE OR REPLACE TRIGGER trg_capacity_check
BEFORE INSERT ON ENROLLMENT
FOR EACH ROW
DECLARE
    v_cap     NUMBER;
    v_current NUMBER;
BEGIN
    SELECT capacity INTO v_cap
    FROM   SECTION
    WHERE  section_id = :NEW.section_id;

    SELECT COUNT(*) INTO v_current
    FROM   ENROLLMENT
    WHERE  section_id = :NEW.section_id
    AND    status = 'Active';

    IF v_current >= v_cap THEN
        RAISE_APPLICATION_ERROR(-20001, 'Section is at full capacity');
    END IF;
END;
/

-- T3: Default enrollment status and date
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

-- T4: Block grade insertion for dropped enrollments
CREATE OR REPLACE TRIGGER trg_no_grade_for_dropped
BEFORE INSERT ON GRADE
FOR EACH ROW
DECLARE
    v_status VARCHAR2(20);
BEGIN
    SELECT status INTO v_status
    FROM   ENROLLMENT
    WHERE  enrollment_id = :NEW.enrollment_id;

    IF v_status = 'Dropped' THEN
        RAISE_APPLICATION_ERROR(-20004, 'Cannot assign grade to a dropped enrollment');
    END IF;
END;
/

-- T5: Audit trail — logs every grade change to GRADE_AUDIT
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

-- =============================================================================
-- SECTION 5: STORED PROCEDURES
-- =============================================================================

-- SP1: Enroll a student (validates duplicates + prerequisites; capacity by trigger)
CREATE OR REPLACE PROCEDURE enroll_student (
    p_student_id  IN NUMBER,
    p_section_id  IN NUMBER
) AS
    v_dup     NUMBER;
    v_prereq  NUMBER;
    v_course  NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_dup
    FROM   ENROLLMENT
    WHERE  student_id = p_student_id AND section_id = p_section_id;

    IF v_dup > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Student is already enrolled in this section');
    END IF;

    SELECT course_id INTO v_course
    FROM   SECTION WHERE section_id = p_section_id;

    SELECT COUNT(*) INTO v_prereq
    FROM   COURSE_PREREQUISITE cp
    WHERE  cp.course_id = v_course
    AND    cp.prerequisite_course_id NOT IN (
        SELECT sec.course_id
        FROM   ENROLLMENT e
        JOIN   SECTION sec ON e.section_id  = sec.section_id
        JOIN   GRADE g     ON e.enrollment_id = g.enrollment_id
        WHERE  e.student_id = p_student_id
        AND    g.letter_grade NOT IN ('F', 'W')
    );

    IF v_prereq > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Prerequisites not yet satisfied for this course');
    END IF;

    INSERT INTO ENROLLMENT (enrollment_id, student_id, section_id, enrollment_date, status)
    VALUES (enrollment_seq.NEXTVAL, p_student_id, p_section_id, SYSDATE, 'Active');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Enrollment successful for student ' || p_student_id);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END enroll_student;
/

-- SP2: Drop an enrollment by setting status to Dropped
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
    WHERE  student_id = p_student_id
    AND    section_id = p_section_id;

    IF v_status = 'Dropped' THEN
        RAISE_APPLICATION_ERROR(-20005, 'This enrollment was already dropped');
    END IF;

    UPDATE ENROLLMENT
    SET    status = 'Dropped'
    WHERE  enrollment_id = v_enroll_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Enrollment ' || v_enroll_id || ' dropped');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20006, 'Enrollment record not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END drop_enrollment;
/

-- SP3: Assign a score and auto-compute letter grade
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

    v_pct := (p_score / v_max) * 100;

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
    DBMS_OUTPUT.PUT_LINE('Grade recorded: ' || v_letter || ' (' || p_score || '/' || v_max || ')');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20007, 'Exam not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
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
        RAISE_APPLICATION_ERROR(-20008, 'Target program does not exist');
    END IF;

    IF v_old_prog = p_new_program_id THEN
        RAISE_APPLICATION_ERROR(-20009, 'Student is already enrolled in this program');
    END IF;

    UPDATE STUDENT SET program_id = p_new_program_id WHERE student_id = p_student_id;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Student ' || p_student_id || ' transferred from ' || v_old_prog || ' to ' || p_new_program_id);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20010, 'Student not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END transfer_student;
/

-- =============================================================================
-- SECTION 6: VIEWS
-- =============================================================================

CREATE OR REPLACE VIEW student_grade_summary AS
SELECT st.student_id,
       st.first_name || ' ' || st.last_name  AS full_name,
       c.title                               AS course,
       t.name                                AS term,
       ROUND(AVG(g.score), 2)               AS avg_score,
       MAX(g.letter_grade)                  AS best_grade
FROM   STUDENT st
JOIN   ENROLLMENT e   ON st.student_id   = e.student_id
JOIN   SECTION sec    ON e.section_id    = sec.section_id
JOIN   COURSE c       ON sec.course_id   = c.course_id
JOIN   TERM t         ON sec.term_id     = t.term_id
JOIN   GRADE g        ON e.enrollment_id = g.enrollment_id
GROUP BY st.student_id, st.first_name, st.last_name, c.title, t.name;

CREATE OR REPLACE VIEW instructor_workload AS
SELECT i.instructor_id,
       i.first_name || ' ' || i.last_name  AS instructor,
       t.name                              AS term,
       COUNT(sec.section_id)              AS sections_taught,
       SUM(sec.capacity)                  AS total_seats
FROM   INSTRUCTOR i
JOIN   SECTION sec ON i.instructor_id = sec.instructor_id
JOIN   TERM t      ON sec.term_id     = t.term_id
GROUP BY i.instructor_id, i.first_name, i.last_name, t.name;

CREATE OR REPLACE VIEW at_risk_students AS
SELECT st.student_id,
       st.first_name || ' ' || st.last_name  AS student,
       st.email,
       p.name                               AS program,
       c.title                              AS course,
       sec.section_number,
       e.status,
       g.score,
       g.letter_grade
FROM   STUDENT st
JOIN   PROGRAM p      ON st.program_id   = p.program_id
JOIN   ENROLLMENT e   ON st.student_id   = e.student_id
JOIN   SECTION sec    ON e.section_id    = sec.section_id
JOIN   COURSE c       ON sec.course_id   = c.course_id
LEFT JOIN GRADE g     ON e.enrollment_id = g.enrollment_id
WHERE  e.status = 'Dropped'
OR     g.letter_grade IN ('F', 'D');

CREATE OR REPLACE VIEW prerequisite_map AS
SELECT c.code   AS course_code,
       c.title  AS course_title,
       p.code   AS requires_code,
       p.title  AS requires_title,
       p.credits AS prereq_credits
FROM   COURSE_PREREQUISITE cp
JOIN   COURSE c ON cp.course_id              = c.course_id
JOIN   COURSE p ON cp.prerequisite_course_id = p.course_id
ORDER BY c.code;

-- =============================================================================
-- SECTION 7: QUICK VERIFICATION QUERIES (run individually to test)
-- =============================================================================

-- Check all tables exist
SELECT table_name FROM user_tables ORDER BY table_name;

-- Check sample data
SELECT 'DEPARTMENT'  tbl, COUNT(*) cnt FROM DEPARTMENT  UNION ALL
SELECT 'INSTRUCTOR',              COUNT(*) FROM INSTRUCTOR  UNION ALL
SELECT 'PROGRAM',                 COUNT(*) FROM PROGRAM     UNION ALL
SELECT 'COURSE',                  COUNT(*) FROM COURSE      UNION ALL
SELECT 'TERM',                    COUNT(*) FROM TERM        UNION ALL
SELECT 'SECTION',                 COUNT(*) FROM SECTION     UNION ALL
SELECT 'STUDENT',                 COUNT(*) FROM STUDENT     UNION ALL
SELECT 'EXAM',                    COUNT(*) FROM EXAM        UNION ALL
SELECT 'ENROLLMENT',              COUNT(*) FROM ENROLLMENT  UNION ALL
SELECT 'GRADE',                   COUNT(*) FROM GRADE;

-- Check views work
SELECT * FROM student_grade_summary;
SELECT * FROM instructor_workload;
SELECT * FROM at_risk_students;
SELECT * FROM prerequisite_map;

-- =============================================================================
-- END OF SCRIPT
-- =============================================================================
