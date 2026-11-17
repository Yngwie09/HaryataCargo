-- Update only the original example contacts; retain assignments, status, GPS, proofs and timestamps.
-- Fictional recipient names and house numbers are for the application's example catalogue.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM schema_migrations WHERE version = 2) THEN
    UPDATE shipments AS s
    SET data = jsonb_set(jsonb_set(s.data, '{penerima}', to_jsonb(v.new_name)), '{alamat}', to_jsonb(v.new_address)),
        revision = s.revision + 1
    FROM (VALUES
      ('Andi Pratama', 'Jl. A. P. Pettarani No. 18, Makassar', 'Michael Runtuwene', 'Jl. Sam Ratulangi No. 18, Kota Manado, Sulawesi Utara'),
      ('Nur Aisyah', 'Jl. Hertasning No. 42, Makassar', 'Claudia Wenas', 'Jl. Piere Tendean No. 42, Kota Manado, Sulawesi Utara'),
      ('Muhammad Fajar', 'Jl. Perintis Kemerdekaan Km. 10, Makassar', 'Steven Warouw', 'Jl. Ahmad Yani No. 10, Kota Manado, Sulawesi Utara'),
      ('Dewi Lestari', 'Jl. Veteran Selatan No. 75, Makassar', 'Angelina Paat', 'Jl. R. W. Monginsidi No. 75, Kota Manado, Sulawesi Utara'),
      ('Rizky Ramadhan', 'Jl. Sultan Alauddin No. 120, Makassar', 'Christian Mandagi', 'Jl. 17 Agustus No. 120, Kota Manado, Sulawesi Utara'),
      ('Siti Rahma', 'Jl. Pengayoman No. 31, Makassar', 'Nathania Lumentut', 'Jl. Babe Palar No. 31, Kota Manado, Sulawesi Utara'),
      ('Arif Hidayat', 'Jl. Boulevard No. 16, Makassar', 'Ricky Sumual', 'Jl. Diponegoro No. 16, Kota Manado, Sulawesi Utara'),
      ('Nadia Putri', 'Jl. Urip Sumoharjo No. 88, Makassar', 'Jessica Tumbel', 'Jl. D. I. Panjaitan No. 88, Kota Manado, Sulawesi Utara'),
      ('Ilham Akbar', 'Jl. Abdullah Daeng Sirua No. 57, Makassar', 'Daniel Roring', 'Jl. Sam Ratulangi No. 57, Kota Manado, Sulawesi Utara'),
      ('Maya Sari', 'Jl. Toddopuli Raya No. 29, Makassar', 'Gracia Mambu', 'Jl. Pumorow No. 29, Kota Manado, Sulawesi Utara'),
      ('Hasan Basri', 'Jl. Baji Gau No. 23, Makassar', 'Andre Sondakh', 'Jl. Tikala Ares No. 23, Kota Manado, Sulawesi Utara'),
      ('Aulia Zahra', 'Jl. Sungai Saddang Baru No. 61, Makassar', 'Michelle Rantung', 'Jl. Santiago No. 61, Kota Manado, Sulawesi Utara'),
      ('Farhan Maulana', 'Jl. Rappocini Raya No. 37, Makassar', 'Kevin Waworuntu', 'Jl. Yos Sudarso No. 37, Kota Manado, Sulawesi Utara'),
      ('Intan Permata', 'Jl. Tamangapa Raya No. 12, Makassar', 'Gabriella Moniaga', 'Jl. A. A. Maramis No. 12, Kota Manado, Sulawesi Utara'),
      ('Reza Saputra', 'Jl. Dg. Tata Raya No. 46, Makassar', 'Samuel Pinontoan', 'Jl. Ring Road No. 46, Kota Manado, Sulawesi Utara')
    ) AS v(old_name, old_address, new_name, new_address)
    WHERE s.resi LIKE 'HC-%'
      AND s.data->>'penerima' = v.old_name
      AND s.data->>'alamat' = v.old_address;
    INSERT INTO schema_migrations(version) VALUES (2);
  END IF;
END;
$$;
