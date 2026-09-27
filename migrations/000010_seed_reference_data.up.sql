-- ============================================================
-- SEED: merchant_categories
-- ============================================================

INSERT INTO merchant_categories (id, name, annual_turnover_min, annual_turnover_max, description) VALUES
    (gen_random_uuid(), 'MICRO',      0,            2000000,    'Turnover up to ₹20L — RBI zero MDR mandate for UPI'),
    (gen_random_uuid(), 'SMALL',      2000001,      20000000,   'Turnover ₹20L–₹2Cr'),
    (gen_random_uuid(), 'MEDIUM',     20000001,     500000000,  'Turnover ₹2Cr–₹50Cr'),
    (gen_random_uuid(), 'LARGE',      500000001,    5000000000, 'Turnover ₹50Cr–₹500Cr'),
    (gen_random_uuid(), 'ENTERPRISE', 5000000001,   NULL,       'Turnover above ₹500Cr');

-- ============================================================
-- SEED: mcc_categories
-- Source: RBI Master Circular on MDR + NPCI MCC list
-- rbi_max_mdr_percentage: stored as decimal fraction (0.02 = 2%)
-- is_zero_mdr: RBI mandates 0% (government, utility <₹50k etc.)
-- ============================================================

INSERT INTO mcc_categories (code, description, rbi_category, rbi_max_mdr_percentage, rbi_max_flat_fee, is_zero_mdr, notes) VALUES

-- GOVERNMENT (0% MDR mandated by RBI)
('9399', 'Government Services (General)',                'GOVERNMENT', 0,      NULL,  true,  'RBI mandates 0% MDR on all government payments'),
('9222', 'Fines / Penalties — Government',              'GOVERNMENT', 0,      NULL,  true,  'RBI mandates 0% MDR'),
('9311', 'Tax Payments',                                'GOVERNMENT', 0,      NULL,  true,  'RBI mandates 0% MDR'),
('9405', 'Post Office',                                 'GOVERNMENT', 0,      NULL,  true,  'RBI mandates 0% MDR'),
('9211', 'Court Costs',                                 'GOVERNMENT', 0,      NULL,  true,  'RBI mandates 0% MDR'),
('9402', 'Postal Services',                             'GOVERNMENT', 0,      NULL,  true,  'RBI mandates 0% MDR'),

-- UTILITY
('4900', 'Utilities — Electric, Gas, Water',            'UTILITY',    0.005,  NULL,  false, 'Max 0.5% MDR per RBI utility cap'),
('4814', 'Telecommunications / Mobile Recharge',        'UTILITY',    0.005,  NULL,  false, 'Telecom MDR capped at 0.5%'),
('4899', 'Cable / Satellite TV',                        'UTILITY',    0.005,  NULL,  false, NULL),
('4911', 'Electric Companies',                          'UTILITY',    0.005,  NULL,  false, NULL),
('4924', 'Natural Gas Distributors',                    'UTILITY',    0.005,  NULL,  false, NULL),
('4941', 'Water Supply',                                'UTILITY',    0.005,  NULL,  false, NULL),

-- FUEL
('5541', 'Service Stations (Petrol/Diesel)',             'FUEL',       0.01,   NULL,  false, 'Fuel MDR max 1% per RBI'),
('5542', 'Automated Fuel Dispensers',                   'FUEL',       0.01,   NULL,  false, 'Fuel MDR max 1%'),
('5172', 'Petroleum and Petroleum Products',            'FUEL',       0.01,   NULL,  false, NULL),

-- EDUCATION
('8211', 'Elementary and Secondary Schools',            'EDUCATION',  0.01,   NULL,  false, 'Education MDR max 1%'),
('8220', 'Colleges, Universities',                      'EDUCATION',  0.01,   NULL,  false, 'Education MDR max 1%'),
('8249', 'Trade / Vocational Schools',                  'EDUCATION',  0.01,   NULL,  false, NULL),
('8299', 'Schools and Educational Services (NEC)',      'EDUCATION',  0.01,   NULL,  false, NULL),

-- HEALTHCARE
('8011', 'Doctors (Not Elsewhere Classified)',          'HEALTHCARE', 0.015,  NULL,  false, NULL),
('8021', 'Dentists and Orthodontists',                  'HEALTHCARE', 0.015,  NULL,  false, NULL),
('8049', 'Chiropodists / Podiatrists',                  'HEALTHCARE', 0.015,  NULL,  false, NULL),
('8050', 'Nursing/Personal Care Facilities',            'HEALTHCARE', 0.015,  NULL,  false, NULL),
('8062', 'Hospitals',                                   'HEALTHCARE', 0.015,  NULL,  false, NULL),
('8099', 'Health Services (NEC)',                       'HEALTHCARE', 0.015,  NULL,  false, NULL),

-- AGRICULTURE
('0742', 'Veterinary Services',                         'AGRICULTURE',0.02,   NULL,  false, NULL),
('5261', 'Lawn / Garden Supply Stores',                 'AGRICULTURE',0.02,   NULL,  false, NULL),
('0763', 'Farm Supplies',                               'AGRICULTURE',0.02,   NULL,  false, NULL),

-- TELECOM (separate from utility)
('4812', 'Telephone Answering Services',                'TELECOM',    0.02,   NULL,  false, NULL),
('4816', 'Computer Networks / Information Services',    'TELECOM',    0.02,   NULL,  false, NULL),

-- TRAVEL
('3000', 'Airlines (Generic)',                          'TRAVEL',     0.02,   NULL,  false, NULL),
('4111', 'Transportation — Suburban / Local',           'TRAVEL',     0.005,  NULL,  false, 'Transit capped at 0.5% per RBI'),
('4112', 'Passenger Railways',                          'TRAVEL',     0.005,  NULL,  false, 'Railways capped at 0.5%'),
('4131', 'Bus Lines',                                   'TRAVEL',     0.005,  NULL,  false, NULL),
('4411', 'Steamship Lines',                             'TRAVEL',     0.02,   NULL,  false, NULL),
('4511', 'Airlines, Air Carriers',                      'TRAVEL',     0.02,   NULL,  false, NULL),
('7011', 'Hotels, Motels, Resorts',                     'TRAVEL',     0.02,   NULL,  false, NULL),
('7512', 'Car Rental Agencies',                         'TRAVEL',     0.02,   NULL,  false, NULL),

-- GENERAL RETAIL / SERVICES
('5411', 'Grocery Stores, Supermarkets',                'GENERAL',    0.02,   NULL,  false, NULL),
('5045', 'Computers, Peripherals, Software',            'GENERAL',    0.02,   NULL,  false, NULL),
('5912', 'Drug Stores and Pharmacies',                  'GENERAL',    0.02,   NULL,  false, NULL),
('5311', 'Department Stores',                           'GENERAL',    0.02,   NULL,  false, NULL),
('5651', 'Family Clothing Stores',                      'GENERAL',    0.02,   NULL,  false, NULL),
('5691', 'Men''s and Women''s Clothing Stores',         'GENERAL',    0.02,   NULL,  false, NULL),
('5732', 'Electronics Stores',                          'GENERAL',    0.02,   NULL,  false, NULL),
('5812', 'Eating Places, Restaurants',                  'GENERAL',    0.02,   NULL,  false, NULL),
('5814', 'Fast Food Restaurants',                       'GENERAL',    0.02,   NULL,  false, NULL),
('5999', 'Miscellaneous Retail Stores',                 'GENERAL',    0.02,   NULL,  false, NULL),
('7372', 'Computer Programming, Data Processing',       'GENERAL',    0.02,   NULL,  false, NULL),
('7995', 'Betting, Casino, Lottery',                    'GENERAL',    0.02,   NULL,  false, 'Subject to additional RBI restrictions'),
('0000', 'Default / Unclassified',                      'GENERAL',    0.02,   NULL,  false, 'Fallback MCC for unclassified merchants');
