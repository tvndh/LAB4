SELECT USER FROM DUAL;

-- Ph?n 2: Bài t?p
-- Câu 1.1: T?o view vw_course_summary - thông tin t?ng quan môn h?c
CREATE OR REPLACE VIEW vw_course_summary AS
SELECT 
    USER AS NGUOI_TRUY_VAN,
    co.MaMonHoc,
    co.TenMonHoc,
    co.HocPhi,
    COUNT(DISTINCT cl.MaLopHoc) AS so_lop,
    COUNT(e.MaSinhVien) AS tong_sv
FROM MON_HOC co
LEFT JOIN LOP_HOC cl ON co.MaMonHoc = cl.MaMonHoc
LEFT JOIN DANG_KY e ON cl.MaLopHoc = e.MaLopHoc
GROUP BY co.MaMonHoc, co.TenMonHoc, co.HocPhi
ORDER BY tong_sv DESC;

-- Kiem tra view:
SELECT * FROM vw_course_summary;

-- Câu 1.2: T?o view vw_student_status - thông tin sinh viên và t?nh tr?ng h?c t?p
CREATE OR REPLACE VIEW vw_student_status AS
SELECT 
    USER AS NGUOI_TRUY_VAN,
    s.MaSinhVien,
    s.Ho || ' ' || s.Ten AS ho_ten,
    COUNT(e.MaLopHoc) AS so_lop_hoc,
    NVL(SUM(co.HocPhi), 0) AS tong_hoc_phi,
    ROUND(AVG(e.DiemTongKet), 2) AS diem_tb
FROM SINH_VIEN s
JOIN DANG_KY e ON s.MaSinhVien = e.MaSinhVien
JOIN LOP_HOC cl ON e.MaLopHoc = cl.MaLopHoc
JOIN MON_HOC co ON cl.MaMonHoc = co.MaMonHoc
GROUP BY s.MaSinhVien, s.Ho, s.Ten
HAVING COUNT(e.MaLopHoc) >= 1
ORDER BY s.MaSinhVien;

-- kiem tra view
SELECT * FROM vw_student_status;

--Câu 1.3: T?o view vw_class_availability - l?p h?c c?n ch? tr?ng
CREATE OR REPLACE VIEW vw_class_availability AS
SELECT 
    USER AS NGUOI_TRUY_VAN,
    cl.MaLopHoc,
    cl.MaMonHoc,
    co.TenMonHoc,
    i.Ho || ' ' || i.Ten AS ten_giao_vien,
    cl.SoLuongToiDa,
    COUNT(e.MaSinhVien) AS so_da_dk,
    cl.SoLuongToiDa - COUNT(e.MaSinhVien) AS cho_trong,
    CASE
        WHEN cl.SoLuongToiDa - COUNT(e.MaSinhVien) > 0 THEN 'C?n ch?'
        ELSE 'H?t ch?'
    END AS trang_thai
FROM LOP_HOC cl
JOIN MON_HOC co ON cl.MaMonHoc = co.MaMonHoc
JOIN GIAO_VIEN i ON cl.MaGiaoVien = i.MaGiaoVien
LEFT JOIN DANG_KY e ON cl.MaLopHoc = e.MaLopHoc
GROUP BY cl.MaLopHoc, cl.MaMonHoc, co.TenMonHoc,
         i.Ho, i.Ten, cl.SoLuongToiDa
HAVING cl.SoLuongToiDa - COUNT(e.MaSinhVien) > 0
ORDER BY cl.MaLopHoc;

-- Kiem tra view
SELECT * FROM vw_class_availability;

--Câu 1.4: T?o view vw_top_courses - ch? ð?c, top 5 môn ðý?c ðãng k? nhi?u nh?t
CREATE OR REPLACE VIEW vw_top_courses AS
SELECT 
    USER AS NGUOI_TRUY_VAN,
    MaMonHoc, 
    TenMonHoc, 
    HocPhi, 
    tong_dk, 
    hang
FROM (
    SELECT co.MaMonHoc,
           co.TenMonHoc,
           co.HocPhi,
           COUNT(e.MaSinhVien) AS tong_dk,
           RANK() OVER (ORDER BY COUNT(e.MaSinhVien) DESC) AS hang
    FROM MON_HOC co
    LEFT JOIN LOP_HOC cl ON co.MaMonHoc = cl.MaMonHoc
    LEFT JOIN DANG_KY e ON cl.MaLopHoc = e.MaLopHoc
    GROUP BY co.MaMonHoc, co.TenMonHoc, co.HocPhi
)
WHERE hang <= 5
ORDER BY hang
WITH READ ONLY;

-- Kiem tra view
SELECT * FROM vw_top_courses;

-- Thu INSERT vao view nay (se bao loi ORA-42399):
INSERT INTO vw_top_courses (MaMonHoc, TenMonHoc, HocPhi)
VALUES (999, 'Test', 100);

--Câu 1.5: T?o view vw_pending_enrollment v?i WITH CHECK OPTION và ki?m tra
CREATE OR REPLACE VIEW vw_pending_enrollment AS
SELECT 
    USER AS NGUOI_TRUY_VAN,
    MaSinhVien, 
    MaLopHoc, 
    NgayGhiDanh,
    NgayDangKy,
    DiemTongKet,
    NguoiTao, 
    NgayTao, 
    NguoiSua, 
    NgaySua
FROM DANG_KY
WHERE DiemTongKet IS NULL
WITH CHECK OPTION;

-- Kiem tra view 
SELECT * FROM vw_pending_enrollment;

-- INSERT 1: DiemTongKet = NULL -> THÀNH CÔNG (th?a ði?u ki?n WHERE c?a View)
INSERT INTO vw_pending_enrollment 
(MaSinhVien, MaLopHoc, NgayGhiDanh,NgayDangKy, NguoiTao, NgayTao, NguoiSua, NgaySua)
VALUES (999, 1, SYSDATE, SYSDATE, USER, SYSDATE, USER, SYSDATE);

-- INSERT 2: DiemTongKet = 85 -> L?I ORA-01402 (vi ph?m WITH CHECK OPTION)
INSERT INTO vw_pending_enrollment 
(MaSinhVien, MaLopHoc, NgayGhiDanh,NgayDangKy, DiemTongKet, NguoiTao, NgayTao, NguoiSua, NgaySua)
VALUES (998, 1, SYSDATE, SYSDATE, 85, USER, SYSDATE, USER, SYSDATE);

-- Câu 2.1: Th? t?c enroll_student - ðãng k? sinh viên vào l?p h?c
CREATE OR REPLACE PROCEDURE sp_dang_ky_lop_hoc
(
    p_MaSinhVien IN NUMBER,
    p_MaLopHoc   IN NUMBER
)
IS
    v_kiem_tra   NUMBER;
    v_suc_chua   NUMBER;
    v_da_dang_ky NUMBER;
BEGIN
    -- ÐK 1: Sinh viên ph?i t?n t?i trong b?ng SINH_VIEN
    SELECT COUNT(*) INTO v_kiem_tra 
    FROM SINH_VIEN 
    WHERE MaSinhVien = p_MaSinhVien;
    
    IF v_kiem_tra = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] Sinh viên ' || p_MaSinhVien || ' không t?n t?i!');
        RETURN;
    END IF;

    -- ÐK 2: L?p h?c ph?i t?n t?i trong b?ng LOP_HOC
    SELECT COUNT(*) INTO v_kiem_tra 
    FROM LOP_HOC 
    WHERE MaLopHoc = p_MaLopHoc;
    
    IF v_kiem_tra = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] L?p h?c ' || p_MaLopHoc || ' không t?n t?i!');
        RETURN;
    END IF;

    -- ÐK 3: Ki?m tra s? s? l?p h?c c?n ch? tr?ng hay không
    SELECT SoLuongToiDa INTO v_suc_chua 
    FROM LOP_HOC 
    WHERE MaLopHoc = p_MaLopHoc;
    
    SELECT COUNT(*) INTO v_da_dang_ky 
    FROM DANG_KY 
    WHERE MaLopHoc = p_MaLopHoc;
    
    -- X? l? trý?ng h?p SoLuongToiDa b? NULL (chýa thi?t l?p gi?i h?n)
    IF v_suc_chua IS NOT NULL AND v_da_dang_ky >= v_suc_chua THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] L?p ' || p_MaLopHoc || ' ð? ð?y! (' || v_da_dang_ky || '/' || v_suc_chua || ')');
        RETURN;
    END IF;

    -- ÐK 4: Ki?m tra sinh viên ð? ðãng k? l?p này trý?c ðó chýa
    SELECT COUNT(*) INTO v_kiem_tra 
    FROM DANG_KY
    WHERE MaSinhVien = p_MaSinhVien AND MaLopHoc = p_MaLopHoc;
    
    IF v_kiem_tra > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] Sinh viên ð? ðãng k? l?p này r?i!');
        RETURN;
    END IF;

    -- ÐK 5: Sinh viên không ðý?c ðãng k? quá 3 l?p
    SELECT COUNT(*) INTO v_kiem_tra 
    FROM DANG_KY 
    WHERE MaSinhVien = p_MaSinhVien;
    
    IF v_kiem_tra >= 3 THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] Sinh viên ð? ðãng k? t?i ða 3 l?p!');
        RETURN;
    END IF;

    -- T?t c? ði?u ki?n ð?u th?a m?n: Th?c hi?n INSERT vào b?ng DANG_KY
    INSERT INTO DANG_KY (
        MaSinhVien, 
        MaLopHoc, 
        NgayGhiDanh, 
        NgayDangKy, 
        NguoiTao, 
        NgayTao, 
        NguoiSua, 
        NgaySua
    )
    VALUES (
        p_MaSinhVien, 
        p_MaLopHoc, 
        SYSDATE, 
        SYSDATE, 
        USER, 
        SYSDATE, 
        USER, 
        SYSDATE
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[THÀNH CÔNG] Ðãng k? hoàn t?t! SV ' || p_MaSinhVien || ' -> L?p ' || p_MaLopHoc);

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[L?I H? TH?NG] ' || SQLERRM);
END sp_dang_ky_lop_hoc;
/


--  KI?M TRA 
BEGIN
    sp_dang_ky_lop_hoc(101, 5);   -- H?p l?
    sp_dang_ky_lop_hoc(999, 5);   -- SV không t?n t?i
    sp_dang_ky_lop_hoc(101, 999); -- L?p không t?n t?i
END;
/
-- Câu 2.2: Th? t?c update_final_grade - c?p nh?t ði?m t?ng k?t
CREATE OR REPLACE PROCEDURE sp_cap_nhat_diem_tong_ket
(
    p_MaSinhVien IN NUMBER,
    p_MaLopHoc   IN NUMBER,
    p_DiemSo     IN NUMBER
)
IS
    v_kiem_tra NUMBER;
    v_diem_cu  NUMBER;
BEGIN
    -- ÐK 1: Ki?m tra ði?m h?p l? (gi? s? thang ði?m 100)
    IF p_DiemSo < 0 OR p_DiemSo > 100 THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] Ði?m không h?p l?! Ph?i n?m trong kho?ng t? 0 ð?n 100.');
        RETURN;
    END IF;

    -- ÐK 2: Ki?m tra sinh viên ð? ðãng k? l?p này chýa (t?n t?i trong DANG_KY)
    SELECT COUNT(*) INTO v_kiem_tra 
    FROM DANG_KY
    WHERE MaSinhVien = p_MaSinhVien AND MaLopHoc = p_MaLopHoc;
    
    IF v_kiem_tra = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] Sinh viên chýa ðãng k? l?p h?c này!');
        RETURN;
    END IF;

    -- Lýu l?i ði?m c? ð? in ra thông báo (n?u có)
    SELECT DiemTongKet INTO v_diem_cu 
    FROM DANG_KY
    WHERE MaSinhVien = p_MaSinhVien AND MaLopHoc = p_MaLopHoc;

    -- BÝ?C 1: C?p nh?t ði?m t?ng k?t vào b?ng DANG_KY
    UPDATE DANG_KY
    SET DiemTongKet = p_DiemSo,
        NguoiSua = USER, 
        NgaySua = SYSDATE
    WHERE MaSinhVien = p_MaSinhVien AND MaLopHoc = p_MaLopHoc;

    -- BÝ?C 2: Ð?ng b? d? li?u sang b?ng DIEM b?ng MERGE INTO 
    MERGE INTO DIEM d
    USING (SELECT p_MaSinhVien AS sid, p_MaLopHoc AS cid FROM DUAL) src
    ON (d.MaSinhVien = src.sid AND d.MaLopHoc = src.cid)
    WHEN MATCHED THEN
        -- N?u ð? có d? li?u trong b?ng DIEM -> C?p nh?t ði?m
        UPDATE SET 
            d.DiemSo = p_DiemSo,
            d.NguoiSua = USER, 
            d.NgaySua = SYSDATE
    WHEN NOT MATCHED THEN
        -- N?u chýa có d? li?u trong b?ng DIEM -> Thêm m?i b?n ghi
        INSERT (MaSinhVien, MaLopHoc, DiemSo, NguoiTao, NgayTao, NguoiSua, NgaySua)
        VALUES (p_MaSinhVien, p_MaLopHoc, p_DiemSo, USER, SYSDATE, USER, SYSDATE);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[THÀNH CÔNG] Ð? c?p nh?t ði?m SV ' || p_MaSinhVien 
                         || ' | L?p ' || p_MaLopHoc 
                         || ' | C?: ' || NVL(TO_CHAR(v_diem_cu),'Chýa có') 
                         || ' -> M?i: ' || p_DiemSo);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[L?I H? TH?NG] ' || SQLERRM);
END sp_cap_nhat_diem_tong_ket;
/

-- KI?M TRA 
BEGIN
    sp_cap_nhat_diem_tong_ket(101, 5, 85);   -- C?p nh?t h?p l?
    sp_cap_nhat_diem_tong_ket(101, 5, 105);  -- Báo l?i ði?m không h?p l?
    sp_cap_nhat_diem_tong_ket(999, 5, 50);   -- Báo l?i chýa ðãng k? l?p
END;
/

--Câu 2.3: Th? t?c transfer_student - chuy?n l?p cho sinh viên
CREATE OR REPLACE PROCEDURE sp_chuyen_lop
(
    p_MaSinhVien IN NUMBER,
    p_MaLopCu    IN NUMBER,
    p_MaLopMoi   IN NUMBER
)
IS
    v_kiem_tra   NUMBER;
    v_suc_chua   NUMBER;
    v_da_dang_ky NUMBER;
BEGIN
    -- ÐK 1: Ki?m tra sinh viên có ðang h?c ? l?p c? hay không
    SELECT COUNT(*) INTO v_kiem_tra 
    FROM DANG_KY
    WHERE MaSinhVien = p_MaSinhVien AND MaLopHoc = p_MaLopCu;
    
    IF v_kiem_tra = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] Sinh viên không có tên trong l?p ' || p_MaLopCu);
        RETURN;
    END IF;

    -- ÐK 2: Ki?m tra l?p m?i c?n ch? tr?ng hay không
    SELECT SoLuongToiDa INTO v_suc_chua 
    FROM LOP_HOC 
    WHERE MaLopHoc = p_MaLopMoi;
    
    SELECT COUNT(*) INTO v_da_dang_ky 
    FROM DANG_KY 
    WHERE MaLopHoc = p_MaLopMoi;
    
    -- X? l? trý?ng h?p SoLuongToiDa b? NULL
    IF v_suc_chua IS NOT NULL AND v_da_dang_ky >= v_suc_chua THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] L?p m?i ' || p_MaLopMoi || ' ð? ð?y!');
        RETURN;
    END IF;

    -- ÐK 3: Ki?m tra sinh viên ð? ðãng k? l?p m?i này trý?c ðó chýa
    SELECT COUNT(*) INTO v_kiem_tra 
    FROM DANG_KY
    WHERE MaSinhVien = p_MaSinhVien AND MaLopHoc = p_MaLopMoi;
    
    IF v_kiem_tra > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] Sinh viên ð? ? trong l?p m?i này r?i!');
        RETURN;
    END IF;

    -- T?T C? ÐI?U KI?N H?P L?: Ti?n hành chuy?n l?p
    SAVEPOINT sp_truoc_chuyen;

    -- Bý?c 1: Xóa thông tin ðãng k? ? l?p c?
    DELETE FROM DANG_KY
    WHERE MaSinhVien = p_MaSinhVien AND MaLopHoc = p_MaLopCu;
    
    SAVEPOINT sp_sau_xoa;

    -- Bý?c 2: Thêm thông tin ðãng k? vào l?p m?i
    INSERT INTO DANG_KY (
        MaSinhVien, 
        MaLopHoc, 
        NgayGhiDanh, 
        NgayDangKy, 
        NguoiTao, 
        NgayTao, 
        NguoiSua, 
        NgaySua
    )
    VALUES (
        p_MaSinhVien, 
        p_MaLopMoi, 
        SYSDATE, 
        SYSDATE, 
        USER, 
        SYSDATE, 
        USER, 
        SYSDATE
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[THÀNH CÔNG] Ð? chuy?n SV ' || p_MaSinhVien 
                         || ' t? l?p ' || p_MaLopCu 
                         || ' sang l?p ' || p_MaLopMoi);
EXCEPTION
    WHEN OTHERS THEN
        -- N?u x?y ra l?i, khôi ph?c l?i tr?ng thái trý?c khi xóa l?p c?
        ROLLBACK TO sp_truoc_chuyen;
        DBMS_OUTPUT.PUT_LINE('[L?I H? TH?NG] Chuy?n l?p th?t b?i: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Ð? rollback v? tr?ng thái ban ð?u.');
END sp_chuyen_lop;
/

-- KI?M TRA 
BEGIN
    sp_chuyen_lop(101, 5, 8);   -- H?p l? (chuy?n SV 101 t? l?p 5 sang l?p 8)
    sp_chuyen_lop(101, 9, 8);   -- L?i: SV không có trong l?p 9
    sp_chuyen_lop(101, 5, 5);   -- L?i: L?p m?i ð? có SV
END;
/

-- Câu 2.4: Th? t?c report_class_detail — in báo cáo chi ti?t l?p h?c
CREATE OR REPLACE PROCEDURE sp_bao_cao_chi_tiet_lop
(
    p_MaLopHoc IN NUMBER
)
IS
    v_kiem_tra      NUMBER;
    v_ten_mon       VARCHAR2(100);
    v_ma_mon        NUMBER;
    v_ten_gv        VARCHAR2(100);
    v_phong_hoc     VARCHAR2(50);
    v_suc_chua      NUMBER;
    
    v_stt           NUMBER := 0;
    v_tong_sv       NUMBER := 0;
    v_tong_diem     NUMBER := 0;
    v_so_luong_diem NUMBER := 0;
    v_xep_loai      VARCHAR2(50);
BEGIN
    -- ÐK 1: Ki?m tra l?p h?c có t?n t?i hay không
    SELECT COUNT(*) INTO v_kiem_tra 
    FROM LOP_HOC 
    WHERE MaLopHoc = p_MaLopHoc;
    
    IF v_kiem_tra = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[L?I] L?p h?c ' || p_MaLopHoc || ' không t?n t?i!');
        RETURN;
    END IF;

    -- BÝ?C 1: L?y thông tin chung c?a l?p h?c, môn h?c và giáo viên
    SELECT 
        mh.TenMonHoc, 
        mh.MaMonHoc,
        gv.Ho || ' ' || gv.Ten,
        lh.PhongHoc, 
        lh.SoLuongToiDa
    INTO 
        v_ten_mon, 
        v_ma_mon, 
        v_ten_gv, 
        v_phong_hoc, 
        v_suc_chua
    FROM LOP_HOC lh
    JOIN MON_HOC mh ON lh.MaMonHoc = mh.MaMonHoc
    JOIN GIAO_VIEN gv ON lh.MaGiaoVien = gv.MaGiaoVien
    WHERE lh.MaLopHoc = p_MaLopHoc;

    -- BÝ?C 2: In ph?n Header c?a báo cáo
    DBMS_OUTPUT.PUT_LINE('=== BÁO CÁO L?P H?C: ' || p_MaLopHoc || ' ===');
    DBMS_OUTPUT.PUT_LINE('Môn h?c   : ' || v_ma_mon || ' - ' || v_ten_mon);
    DBMS_OUTPUT.PUT_LINE('Giáo viên : ' || v_ten_gv);
    DBMS_OUTPUT.PUT_LINE('Ph?ng h?c : ' || NVL(v_phong_hoc, 'Chýa x?p ph?ng'));
    DBMS_OUTPUT.PUT_LINE('S?c ch?a  : ' || NVL(TO_CHAR(v_suc_chua), 'Không gi?i h?n') || ' ch?');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 55, '-'));
    DBMS_OUTPUT.PUT_LINE('DANH SÁCH SINH VIÊN:');
    DBMS_OUTPUT.PUT_LINE(RPAD('STT', 4) || ' | ' || RPAD('H? Tên', 25) || ' | ' || LPAD('Ði?m TK', 8) || ' | X?p lo?i');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 55, '-'));

    -- BÝ?C 3: Duy?t danh sách sinh viên trong l?p và in ra
    FOR rec IN (
        SELECT 
            sv.Ho || ' ' || sv.Ten AS ho_ten,
            dk.DiemTongKet
        FROM DANG_KY dk
        JOIN SINH_VIEN sv ON dk.MaSinhVien = sv.MaSinhVien
        WHERE dk.MaLopHoc = p_MaLopHoc
        ORDER BY sv.Ten, sv.Ho  -- S?p x?p theo tên trý?c, h? sau
    ) LOOP
        v_stt := v_stt + 1;
        v_tong_sv := v_tong_sv + 1;

        -- Phân lo?i h?c l?c d?a trên ði?m (Gi? ð?nh thang ði?m 100)
        IF rec.DiemTongKet IS NULL THEN
            v_xep_loai := 'Chýa có ði?m';
        ELSIF rec.DiemTongKet >= 90 THEN
            v_xep_loai := 'A';
            v_tong_diem := v_tong_diem + rec.DiemTongKet; 
            v_so_luong_diem := v_so_luong_diem + 1;
        ELSIF rec.DiemTongKet >= 80 THEN
            v_xep_loai := 'B';
            v_tong_diem := v_tong_diem + rec.DiemTongKet; 
            v_so_luong_diem := v_so_luong_diem + 1;
        ELSIF rec.DiemTongKet >= 70 THEN
            v_xep_loai := 'C';
            v_tong_diem := v_tong_diem + rec.DiemTongKet; 
            v_so_luong_diem := v_so_luong_diem + 1;
        ELSIF rec.DiemTongKet >= 50 THEN
            v_xep_loai := 'D';
            v_tong_diem := v_tong_diem + rec.DiemTongKet; 
            v_so_luong_diem := v_so_luong_diem + 1;
        ELSE
            v_xep_loai := 'F';
            v_tong_diem := v_tong_diem + rec.DiemTongKet; 
            v_so_luong_diem := v_so_luong_diem + 1;
        END IF;

        -- In thông tin t?ng sinh viên
        DBMS_OUTPUT.PUT_LINE(
            LPAD(v_stt, 3) || '  | '
            || RPAD(rec.ho_ten, 25) || ' | '
            || LPAD(NVL(TO_CHAR(rec.DiemTongKet), 'NULL'), 8) || ' | '
            || v_xep_loai
        );
    END LOOP;

    -- BÝ?C 4: In ph?n Footer c?a báo cáo (Th?ng kê t?ng quan)
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 55, '-'));
    DBMS_OUTPUT.PUT_LINE('T?ng s? sinh viên   : ' || v_tong_sv);
    
    IF v_so_luong_diem > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Ði?m trung b?nh l?p : ' || ROUND(v_tong_diem / v_so_luong_diem, 2));
    ELSE
        DBMS_OUTPUT.PUT_LINE('Ði?m trung b?nh l?p : Chýa có d? li?u ði?m');
    END IF;
    
END sp_bao_cao_chi_tiet_lop;
/

-- KI?M TRA
BEGIN
    sp_bao_cao_chi_tiet_lop(1);
END;
/

-- Câu 2.5: Th? t?c sync_grade_from_enrollment - ð?ng b? ði?m t? ENROLLMENT sang GRADE
CREATE OR REPLACE PROCEDURE sp_dong_bo_diem_tu_dang_ky
IS
    v_kiem_tra   NUMBER;
    v_dem_insert NUMBER := 0;
    v_dem_update NUMBER := 0;
BEGIN
    -- Quét toàn b? d? li?u trong b?ng DANG_KY mà sinh viên ð? có ði?m
    FOR rec IN (
        SELECT MaSinhVien, MaLopHoc, DiemTongKet
        FROM DANG_KY
        WHERE DiemTongKet IS NOT NULL
    ) LOOP
        -- Ki?m tra xem b?n ghi này ð? t?n t?i trong b?ng DIEM hay chýa
        SELECT COUNT(*) INTO v_kiem_tra 
        FROM DIEM
        WHERE MaSinhVien = rec.MaSinhVien AND MaLopHoc = rec.MaLopHoc;

        IF v_kiem_tra = 0 THEN
            -- Chýa có -> Th?c hi?n INSERT m?i
            INSERT INTO DIEM (
                MaSinhVien, 
                MaLopHoc, 
                DiemSo, 
                NguoiTao, 
                NgayTao, 
                NguoiSua, 
                NgaySua
            )
            VALUES (
                rec.MaSinhVien, 
                rec.MaLopHoc, 
                rec.DiemTongKet,
                USER, 
                SYSDATE, 
                USER, 
                SYSDATE
            );
            v_dem_insert := v_dem_insert + 1;
        ELSE
            -- Ð? có -> Th?c hi?n UPDATE l?i ði?m s?
            UPDATE DIEM
            SET DiemSo = rec.DiemTongKet,
                NguoiSua = USER, 
                NgaySua = SYSDATE
            WHERE MaSinhVien = rec.MaSinhVien AND MaLopHoc = rec.MaLopHoc;
            
            v_dem_update := v_dem_update + 1;
        END IF;
    END LOOP;

    -- Lýu thay ð?i vào CSDL
    COMMIT;
    
    -- In báo cáo k?t qu? ð?ng b?
    DBMS_OUTPUT.PUT_LINE('[THÀNH CÔNG] Ð?ng b? d? li?u hoàn t?t!');
    DBMS_OUTPUT.PUT_LINE('- S? b?n ghi thêm m?i (INSERT) : ' || v_dem_insert);
    DBMS_OUTPUT.PUT_LINE('- S? b?n ghi c?p nh?t (UPDATE) : ' || v_dem_update);

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[L?I H? TH?NG] Ð?ng b? th?t b?i: ' || SQLERRM);
END sp_dong_bo_diem_tu_dang_ky;
/

-- KI?M TRA 

BEGIN 
    sp_dong_bo_diem_tu_dang_ky; 
END; 
/

--Câu 3.1: Trigger trg_check_capacity - ki?m tra s?c ch?a khi ðãng k?
CREATE OR REPLACE TRIGGER trg_kiem_tra_si_so
FOR INSERT ON DANG_KY
COMPOUND TRIGGER
    
    -- Khai báo bi?n toàn c?c trong ph?m vi Trigger
    v_suc_chua   NUMBER;
    v_da_dang_ky NUMBER;
    v_MaLopHoc   NUMBER;

    -- BÝ?C 1: L?y M? l?p h?c ? m?c d?ng (BEFORE EACH ROW)
    BEFORE EACH ROW IS
    BEGIN
        v_MaLopHoc := :NEW.MaLopHoc;
    END BEFORE EACH ROW;

    -- BÝ?C 2: Ki?m tra s? s? ? m?c l?nh (AFTER STATEMENT) - Lúc này b?ng ð? h?t b? khóa
    AFTER STATEMENT IS
    BEGIN
        -- L?y s?c ch?a t?i ða c?a l?p h?c
        SELECT SoLuongToiDa INTO v_suc_chua
        FROM LOP_HOC 
        WHERE MaLopHoc = v_MaLopHoc;

        -- N?u l?p có gi?i h?n s?c ch?a th? m?i ki?m tra
        IF v_suc_chua IS NOT NULL THEN
            -- Ð?m s? sinh viên hi?n ð? ðãng k? trong l?p
            SELECT COUNT(*) INTO v_da_dang_ky
            FROM DANG_KY 
            WHERE MaLopHoc = v_MaLopHoc;

            -- T? ch?i thao tác INSERT n?u l?p ð? ð?y
            IF v_da_dang_ky > v_suc_chua THEN
                RAISE_APPLICATION_ERROR(
                    -20010,
                    '[L?I] L?p ' || v_MaLopHoc || ' ð? ð?y! (T?i ða ' || v_suc_chua || ' ch?)'
                );
            END IF;
        END IF;
    END AFTER STATEMENT;

END trg_kiem_tra_si_so;
/

-- KI?M TRA 
INSERT INTO DANG_KY (
    MaSinhVien, 
    MaLopHoc, 
    NgayGhiDanh, 
    NgayDangKy, 
    NguoiTao, 
    NgayTao, 
    NguoiSua, 
    NgaySua
) VALUES (999,1,SYSDATE,SYSDATE,USER,SYSDATE,USER, SYSDATE
);

--Câu 3.2: Trigger trg_grade_audit_log - ghi nh?t k? thay ð?i ði?m
-- 1. T?o b?ng lýu tr? nh?t k? s?a ði?m
CREATE TABLE NHAT_KY_SUA_DIEM (
    MaLog       NUMBER GENERATED ALWAYS AS IDENTITY,
    MaSinhVien  NUMBER(8, 0),
    MaLopHoc    NUMBER(8, 0),
    DiemCu      NUMBER(3, 0),
    DiemMoi     NUMBER(3, 0),
    NguoiSua    VARCHAR2(30),
    ThoiGian    DATE,
    
    CONSTRAINT PK_NHAT_KY_SUA_DIEM PRIMARY KEY (MaLog)
);
/

-- 2. T?o Trigger ghi log khi có c?p nh?t ði?m
CREATE OR REPLACE TRIGGER trg_nhat_ky_sua_diem
AFTER UPDATE OF DiemTongKet ON DANG_KY
FOR EACH ROW
BEGIN
    -- Ch? ghi log khi ði?m TH?C S? thay ð?i
    IF (:OLD.DiemTongKet IS NULL AND :NEW.DiemTongKet IS NOT NULL)
       OR (:OLD.DiemTongKet IS NOT NULL AND :NEW.DiemTongKet IS NULL) 
       OR (:OLD.DiemTongKet != :NEW.DiemTongKet)
    THEN
        INSERT INTO NHAT_KY_SUA_DIEM (
            MaSinhVien, 
            MaLopHoc, 
            DiemCu, 
            DiemMoi, 
            NguoiSua, 
            ThoiGian
        ) VALUES (
            :OLD.MaSinhVien, 
            :OLD.MaLopHoc, 
            :OLD.DiemTongKet,
            :NEW.DiemTongKet, 
            USER, 
            SYSDATE
        );
    END IF;
END trg_nhat_ky_sua_diem;
/

-- KI?M TRA
-- Bý?c 1: Th? c?p nh?t ði?m cho m?t sinh viên ð? t?n t?i trong l?p
UPDATE DANG_KY 
SET DiemTongKet = 85
WHERE MaSinhVien = 101 AND MaLopHoc = 1;

COMMIT;

-- Bý?c 2: Truy v?n b?ng Log ð? xem Trigger ð? t? ð?ng ghi nh?n l?ch s? chýa
SELECT * FROM NHAT_KY_SUA_DIEM;

--Câu 3.3: Trigger trg_prevent_course_delete - ngãn xóa môn h?c ðang có l?p
CREATE OR REPLACE TRIGGER trg_ngan_xoa_mon_hoc
BEFORE DELETE ON MON_HOC
FOR EACH ROW
DECLARE
    v_so_lop NUMBER;
BEGIN
    -- Ð?m s? lý?ng l?p h?c ðang s? d?ng môn h?c chu?n b? xóa
    SELECT COUNT(*) INTO v_so_lop
    FROM LOP_HOC 
    WHERE MaMonHoc = :OLD.MaMonHoc;

    -- N?u v?n c?n l?p h?c tham chi?u ð?n môn h?c này th? báo l?i và ch?n l?nh xóa
    IF v_so_lop > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20020,
            '[L?I] Không th? xóa môn h?c ' || :OLD.MaMonHoc ||
            ' (' || :OLD.TenMonHoc || ') ' ||
            'v? c?n ' || v_so_lop || ' l?p h?c ðang t?n t?i!'
        );
    END IF;
    
    -- N?u v_so_lop = 0: Trigger k?t thúc b?nh thý?ng, Oracle ti?n hành xóa môn h?c
END trg_ngan_xoa_mon_hoc;
/

-- KI?M TRA 
-- 1. Ki?m tra xóa môn h?c ÐANG CÓ l?p
DELETE FROM MON_HOC WHERE MaMonHoc = 10; 

-- 2. Ki?m tra xóa môn h?c KHÔNG CÓ l?p
DELETE FROM MON_HOC WHERE MaMonHoc = 999; 
ROLLBACK;

--Câu 3.4: Trigger trg_update_grade_summary - c?p nh?t b?ng th?ng kê t? ð?ng
CREATE TABLE THONG_KE_DIEM_LOP (
    MaLopHoc NUMBER(8, 0) PRIMARY KEY,
    SoLuongSV NUMBER,
    DiemTrungBinh NUMBER(5,2),
    DiemCaoNhat NUMBER(3, 0),
    DiemThapNhat NUMBER(3, 0),
    ThoiGianCapNhat DATE
);
/

CREATE OR REPLACE TRIGGER trg_cap_nhat_thong_ke_diem
AFTER INSERT OR UPDATE OR DELETE ON DANG_KY
FOR EACH ROW
DECLARE
    v_MaLopHoc NUMBER;
    v_so_sv NUMBER;
    v_diem_tb NUMBER;
    v_max_d NUMBER;
    v_min_d NUMBER;
BEGIN
    -- L?y M? L?p H?c d?a trên lo?i s? ki?n
    IF INSERTING OR UPDATING THEN
        v_MaLopHoc := :NEW.MaLopHoc;
    ELSE -- DELETING
        v_MaLopHoc := :OLD.MaLopHoc;
    END IF;

    -- Tính l?i th?ng kê cho l?p b? ?nh hý?ng
    SELECT COUNT(DiemTongKet),
           ROUND(AVG(DiemTongKet), 2),
           MAX(DiemTongKet),
           MIN(DiemTongKet)
    INTO v_so_sv, v_diem_tb, v_max_d, v_min_d
    FROM DANG_KY
    WHERE MaLopHoc = v_MaLopHoc AND DiemTongKet IS NOT NULL;

    -- MERGE INTO c?p nh?t ho?c thêm m?i
    MERGE INTO THONG_KE_DIEM_LOP cgs
    USING (SELECT v_MaLopHoc AS cid FROM DUAL) src
    ON (cgs.MaLopHoc = src.cid)
    WHEN MATCHED THEN
        UPDATE SET
            SoLuongSV = v_so_sv,
            DiemTrungBinh = v_diem_tb,
            DiemCaoNhat = v_max_d,
            DiemThapNhat = v_min_d,
            ThoiGianCapNhat = SYSDATE
    WHEN NOT MATCHED THEN
        INSERT (MaLopHoc, SoLuongSV, DiemTrungBinh, DiemCaoNhat, DiemThapNhat, ThoiGianCapNhat)
        VALUES (v_MaLopHoc, v_so_sv, v_diem_tb, v_max_d, v_min_d, SYSDATE);
END trg_cap_nhat_thong_ke_diem;
/

-- Ki?m tra trigger:
UPDATE DANG_KY SET DiemTongKet = 90 WHERE MaSinhVien=101 AND MaLopHoc=1;
COMMIT;
SELECT * FROM THONG_KE_DIEM_LOP WHERE MaLopHoc = 1;

--Câu 4.1: H? th?ng báo cáo hoàn ch?nh - View + Procedure + Cursor
--Bý?c 1: T?o View vw_instructor_workload
CREATE OR REPLACE VIEW vw_instructor_workload AS
SELECT 
    gv.MaGiaoVien AS instructorid,
    gv.Ho || ' ' || gv.Ten AS ho_ten,
    COUNT(DISTINCT lh.MaLopHoc) AS so_lop,
    COUNT(dk.MaSinhVien) AS tong_sv,
    ROUND(AVG(dk.DiemTongKet), 2) AS diem_tb_chung,
    CASE
        WHEN COUNT(DISTINCT lh.MaLopHoc) >= 3 THEN 'Ban nhieu'
        WHEN COUNT(DISTINCT lh.MaLopHoc) = 2 THEN 'Binh thuong'
        ELSE 'Nhe nhang'
    END AS muc_ban
FROM GIAO_VIEN gv
LEFT JOIN LOP_HOC lh ON gv.MaGiaoVien = lh.MaGiaoVien
LEFT JOIN DANG_KY dk ON lh.MaLopHoc = dk.MaLopHoc
GROUP BY gv.MaGiaoVien, gv.Ho, gv.Ten
ORDER BY so_lop DESC;
/

SELECT * FROM vw_instructor_workload;
-- Bý?c 1.5: T?o View vw_top_courses
CREATE OR REPLACE VIEW vw_top_courses AS
SELECT 
    mh.TenMonHoc AS description,
    COUNT(dk.MaSinhVien) AS tong_dk,
    RANK() OVER (ORDER BY COUNT(dk.MaSinhVien) DESC) AS hang
FROM MON_HOC mh
JOIN LOP_HOC lh ON mh.MaMonHoc = lh.MaMonHoc
JOIN DANG_KY dk ON lh.MaLopHoc = dk.MaLopHoc
GROUP BY mh.TenMonHoc;
/
--Bý?c 2: Th? t?c print_system_report
CREATE OR REPLACE PROCEDURE print_system_report
IS
    v_so_mon NUMBER;
    v_so_lop NUMBER;
    v_so_sv NUMBER;
    v_so_gv NUMBER;
BEGIN
    -- Lay so lieu tong the
    SELECT COUNT(*) INTO v_so_mon FROM MON_HOC;
    SELECT COUNT(*) INTO v_so_lop FROM LOP_HOC;
    SELECT COUNT(*) INTO v_so_sv FROM SINH_VIEN;
    SELECT COUNT(*) INTO v_so_gv FROM GIAO_VIEN;

    -- In header
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE(' BAO CAO TOAN HE THONG QUAN LY KHOA HOC');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('Tong so mon hoc : ' || v_so_mon);
    DBMS_OUTPUT.PUT_LINE('Tong so lop hoc : ' || v_so_lop);
    DBMS_OUTPUT.PUT_LINE('Tong so sinh vien: ' || v_so_sv);
    DBMS_OUTPUT.PUT_LINE('Tong so giao vien: ' || v_so_gv);
    DBMS_OUTPUT.PUT_LINE(RPAD('-',50,'-'));

    -- Phan 1: Thong ke giao vien (dung view vw_instructor_workload)
    DBMS_OUTPUT.PUT_LINE('THONG KE GIAO VIEN:');
    FOR rec IN (SELECT * FROM vw_instructor_workload) LOOP
        DBMS_OUTPUT.PUT_LINE(
            ' ' || RPAD(rec.ho_ten, 25)
            || ' | ' || LPAD(rec.so_lop, 2) || ' lop'
            || ' | ' || LPAD(rec.tong_sv, 3) || ' SV'
            || ' | DTB: ' || NVL(TO_CHAR(rec.diem_tb_chung),'--')
            || ' | ' || rec.muc_ban
        );
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(RPAD('-',50,'-'));

    -- Phan 2: Top 3 mon hoc (dung view vw_top_courses)
    DBMS_OUTPUT.PUT_LINE('TOP 3 MON HOC DUOC DANG KY NHIEU NHAT:');
    FOR rec IN (SELECT * FROM vw_top_courses WHERE hang <= 3) LOOP
        DBMS_OUTPUT.PUT_LINE(
            ' ' || rec.hang || '. '
            || RPAD(rec.description, 30)
            || ' - ' || rec.tong_dk || ' luot dang ky'
        );
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('============================================');
END print_system_report;
/

-- Chay bao cao:
SET SERVEROUTPUT ON SIZE 1000000;
BEGIN 
    print_system_report; 
END;
/