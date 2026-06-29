-- ============================================================
-- DAMG 6210 – Team 3
-- Voice-Call Chat & Social Interaction Platform
-- Database Implementation: DDL + DML + Views + Constraints
-- ============================================================

-- ============================================================
-- 0. CREATE DATABASE
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'VoiceCallPlatformDB')
    CREATE DATABASE VoiceCallPlatformDB;
GO

USE VoiceCallPlatformDB;
GO

-- ============================================================
-- 1. DROP TABLES (safe teardown in dependency order)
-- ============================================================
IF OBJECT_ID('dbo.AudioCallProvider',     'U') IS NOT NULL DROP TABLE dbo.AudioCallProvider;
IF OBJECT_ID('dbo.AudioCall',             'U') IS NOT NULL DROP TABLE dbo.AudioCall;
IF OBJECT_ID('dbo.RoomTagAssignment',     'U') IS NOT NULL DROP TABLE dbo.RoomTagAssignment;
IF OBJECT_ID('dbo.RoomTagCatalog',        'U') IS NOT NULL DROP TABLE dbo.RoomTagCatalog;
IF OBJECT_ID('dbo.ProviderTagAssignment', 'U') IS NOT NULL DROP TABLE dbo.ProviderTagAssignment;
IF OBJECT_ID('dbo.ProviderTagCatalog',    'U') IS NOT NULL DROP TABLE dbo.ProviderTagCatalog;
IF OBJECT_ID('dbo.Tip',                   'U') IS NOT NULL DROP TABLE dbo.Tip;
IF OBJECT_ID('dbo.RoomMessage',           'U') IS NOT NULL DROP TABLE dbo.RoomMessage;
IF OBJECT_ID('dbo.RoomProvider',          'U') IS NOT NULL DROP TABLE dbo.RoomProvider;
IF OBJECT_ID('dbo.Room',                  'U') IS NOT NULL DROP TABLE dbo.Room;
IF OBJECT_ID('dbo.Member',                'U') IS NOT NULL DROP TABLE dbo.Member;
IF OBJECT_ID('dbo.Provider',              'U') IS NOT NULL DROP TABLE dbo.Provider;
IF OBJECT_ID('dbo.[User]',                'U') IS NOT NULL DROP TABLE dbo.[User];
GO

-- ============================================================
-- 2. DROP HELPER FUNCTIONS (if re-running)
-- ============================================================
IF OBJECT_ID('dbo.fn_ValidateTipAmount',    'FN') IS NOT NULL DROP FUNCTION dbo.fn_ValidateTipAmount;
IF OBJECT_ID('dbo.fn_ValidateCallDuration', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_ValidateCallDuration;
IF OBJECT_ID('dbo.fn_ComputeCallDuration',  'FN') IS NOT NULL DROP FUNCTION dbo.fn_ComputeCallDuration;
IF OBJECT_ID('dbo.fn_ComputeArtistEarn',    'FN') IS NOT NULL DROP FUNCTION dbo.fn_ComputeArtistEarn;

GO

-- ============================================================
-- 3. SCALAR FUNCTIONS (used for CHECK constraints & computed columns)
-- ============================================================

-- 3A. Validate tip amount: must be positive and <= 9999
CREATE FUNCTION dbo.fn_ValidateTipAmount(@amount INT)
RETURNS INT
AS
BEGIN
    IF @amount > 0 AND @amount <= 9999
        RETURN 1;
    RETURN 0;
END;
GO

-- 3B. Validate call duration: must be positive
CREATE FUNCTION dbo.fn_ValidateCallDuration(@seconds INT)
RETURNS INT
AS
BEGIN
    IF @seconds > 0
        RETURN 1;
    RETURN 0;
END;
GO

-- 3C. Compute call duration in seconds from two DATETIME values
--     Used as computed column in AudioCall
CREATE FUNCTION dbo.fn_ComputeCallDuration(@start DATETIME, @end_time DATETIME)
RETURNS INT
AS
BEGIN
    IF @end_time IS NULL OR @start IS NULL
        RETURN NULL;
    RETURN DATEDIFF(SECOND, @start, @end_time);
END;
GO



-- 3D. Compute artist earnings after 20% platform fee
--     Used as computed column in AudioCallProvider
CREATE FUNCTION dbo.fn_ComputeArtistEarn(@price_tokens INT, @duration_seconds INT)
RETURNS INT
AS
BEGIN
    IF @price_tokens IS NULL OR @duration_seconds IS NULL
        RETURN NULL;
    RETURN CAST(@price_tokens * @duration_seconds / 60.0 * 0.80 AS INT);
END;
GO

-- ============================================================
-- 4. CREATE TABLES
-- ============================================================

-- 4.1 User (core identity & authentication)
CREATE TABLE dbo.[User] (
    id                  INT             NOT NULL IDENTITY(1,1),
    name                VARCHAR(100)    NULL,
    email               VARCHAR(255)    NOT NULL,
    email_verified_at   DATETIME        NULL,
    email_verify_status BIT             NOT NULL DEFAULT 0,
    password            VARCHAR(255)    NOT NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'active',
    type                VARCHAR(20)     NOT NULL DEFAULT 'user',
    country_code        VARCHAR(10)     NULL,
    phone               VARCHAR(30)     NULL,
    phone_verify_status BIT             NOT NULL DEFAULT 0,
    phone_verified_at   DATETIME        NULL,
    created_at          DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_User          PRIMARY KEY (id),
    CONSTRAINT UQ_User_Email    UNIQUE (email),
    CONSTRAINT CK_User_Status   CHECK (status IN ('active', 'suspended', 'deleted')),
    CONSTRAINT CK_User_Type     CHECK (type   IN ('user', 'admin'))
);
GO

-- 4.2 Member (role extension for general users / audience)
CREATE TABLE dbo.Member (
    id              INT             NOT NULL IDENTITY(1,1),
    user_id         INT             NOT NULL,
    nickname        VARCHAR(100)    NULL,
    token_balance   INT             NOT NULL DEFAULT 0,
    vip_level       INT             NOT NULL DEFAULT 0,
    CONSTRAINT PK_Member        PRIMARY KEY (id),
    CONSTRAINT UQ_Member_User   UNIQUE (user_id),
    CONSTRAINT FK_Member_User
        FOREIGN KEY (user_id) REFERENCES dbo.[User](id)
        ON DELETE CASCADE,
    CONSTRAINT CK_Member_Tokens CHECK (token_balance >= 0),
    CONSTRAINT CK_Member_VIP   CHECK (vip_level >= 0)
);
GO

-- 4.3 Provider (role extension for service providers)
CREATE TABLE dbo.Provider (
    id                      INT             NOT NULL IDENTITY(1,1),
    user_id                 INT             NOT NULL,
    display_name            VARCHAR(100)    NULL,
    service_type            VARCHAR(20)     NULL,
    bio                     TEXT            NULL,
    avatar_url              VARCHAR(500)    NULL,
    level                   INT             NOT NULL DEFAULT 1,
    price                   INT             NOT NULL DEFAULT 0,  -- tokens per minute
    platform_fee_percentage DECIMAL(5,2)   NOT NULL DEFAULT 20.00,
    rating                  DECIMAL(3,2)   NULL,
    total_minutes           INT             NOT NULL DEFAULT 0,
    is_available            BIT             NOT NULL DEFAULT 1,
    is_verified             BIT             NOT NULL DEFAULT 0,
    last_active_at          DATETIME        NULL,
    profile_completed_at    DATETIME        NULL,
    created_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_Provider          PRIMARY KEY (id),
    CONSTRAINT UQ_Provider_User     UNIQUE (user_id),
    CONSTRAINT FK_Provider_User
        FOREIGN KEY (user_id) REFERENCES dbo.[User](id)
        ON DELETE CASCADE,
    CONSTRAINT CK_Provider_Rating   CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5)),
    CONSTRAINT CK_Provider_Fee      CHECK (platform_fee_percentage >= 0 AND platform_fee_percentage <= 100)
);
GO

-- 4.4 Room (chat / call session environment)
CREATE TABLE dbo.Room (
    id                      INT             NOT NULL IDENTITY(1,1),
    owner_user_id           INT             NOT NULL,
    name                    VARCHAR(200)    NOT NULL,
    description             TEXT            NULL,
    is_group                BIT             NOT NULL DEFAULT 1,
      service_fee             INT             NOT NULL DEFAULT 0,
    default_tip_amount           INT             NOT NULL DEFAULT 0,
    max_provider_count      INT             NOT NULL DEFAULT 5,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'active',
    service_type            VARCHAR(20)     NOT NULL DEFAULT 'public',
    created_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_Room              PRIMARY KEY (id),
    CONSTRAINT FK_Room_User
        FOREIGN KEY (owner_user_id) REFERENCES dbo.[User](id),
    CONSTRAINT CK_Room_Status       CHECK (status       IN ('active', 'closed', 'dissolved')),
    CONSTRAINT CK_Room_ServiceType  CHECK (service_type IN ('public', 'private', 'premium'))
);
GO

-- 4.5 RoomProvider (junction: providers participating in rooms)
CREATE TABLE dbo.RoomProvider (
    room_id         INT             NOT NULL,
    provider_id        INT             NOT NULL,
    user_id         INT             NOT NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'active',
    tip_received    BIT             NOT NULL DEFAULT 0,
    tip_amount      INT             NOT NULL DEFAULT 0,
    joined_at       DATETIME        NOT NULL DEFAULT GETDATE(),
    selected_at     DATETIME        NULL,
    left_at         DATETIME        NULL,
    created_at      DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at      DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_RoomProvider PRIMARY KEY (room_id, provider_id),
    CONSTRAINT FK_RoomProvider_Room
        FOREIGN KEY (room_id)   REFERENCES dbo.Room(id),
    CONSTRAINT FK_RoomProvider_Provider
        FOREIGN KEY (provider_id)  REFERENCES dbo.Provider(id),
    CONSTRAINT FK_RoomProvider_User
        FOREIGN KEY (user_id)   REFERENCES dbo.[User](id),
    CONSTRAINT CK_RoomProvider_Status
        CHECK (status IN ('active', 'inactive', 'removed'))
);
GO

-- 4.6 RoomMessage (messages sent within rooms)
--     message_id IDENTITY ensures correct ordering and unique identification
CREATE TABLE dbo.RoomMessage (
    message_id      INT             NOT NULL IDENTITY(1,1),
    room_id         INT             NOT NULL,
    user_id         INT             NOT NULL,
    message         TEXT            NOT NULL,
    media           VARCHAR(500)    NULL,
    message_type    VARCHAR(20)     NOT NULL DEFAULT 'text',
    gift_data       VARCHAR(500)    NULL,
    access          BIT             NOT NULL DEFAULT 1,
    created_at      DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at      DATETIME        NOT NULL DEFAULT GETDATE(),
    deleted_at      DATETIME        NULL,
    CONSTRAINT PK_RoomMessage PRIMARY KEY (message_id),
    CONSTRAINT FK_RoomMessage_Room
        FOREIGN KEY (room_id) REFERENCES dbo.Room(id),
    CONSTRAINT FK_RoomMessage_User
        FOREIGN KEY (user_id) REFERENCES dbo.[User](id),
    CONSTRAINT CK_RoomMessage_Type
        CHECK (message_type IN ('text', 'image', 'gif', 'gift', 'system'))
);
GO

-- 4.7 ProviderTagCatalog (predefined tag library for providers)
CREATE TABLE dbo.ProviderTagCatalog (
    id          INT             NOT NULL IDENTITY(1,1),
    name        VARCHAR(50)     NOT NULL,
    display_name VARCHAR(100)   NULL,
    description VARCHAR(255)    NULL,
    color       VARCHAR(20)     NULL,
    category    VARCHAR(50)     NULL,
    sort_order  INT             NOT NULL DEFAULT 0,
    is_active   BIT             NOT NULL DEFAULT 1,
    created_at  DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at  DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_ProviderTagCatalog    PRIMARY KEY (id),
    CONSTRAINT UQ_ProviderTagCatalog    UNIQUE (name)
);
GO

-- 4.8 ProviderTagAssignment (junction: tags mapped to providers)
CREATE TABLE dbo.ProviderTagAssignment (
    tag_id      INT NOT NULL,
    provider_id INT NOT NULL,
    CONSTRAINT PK_ProviderTagAssignment PRIMARY KEY (tag_id, provider_id),
    CONSTRAINT FK_PTA_Tag
        FOREIGN KEY (tag_id)      REFERENCES dbo.ProviderTagCatalog(id),
    CONSTRAINT FK_PTA_Provider
        FOREIGN KEY (provider_id) REFERENCES dbo.Provider(id)
);
GO

-- 4.9 RoomTagCatalog (predefined category library for rooms)
CREATE TABLE dbo.RoomTagCatalog (
    id          INT             NOT NULL IDENTITY(1,1),
    name        VARCHAR(50)     NOT NULL,
    created_at  DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at  DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_RoomTagCatalog    PRIMARY KEY (id),
    CONSTRAINT UQ_RoomTagCatalog    UNIQUE (name)
);
GO

-- 4.10 RoomTagAssignment (junction: tags mapped to rooms)
CREATE TABLE dbo.RoomTagAssignment (
    room_id     INT NOT NULL,
    room_tag_id INT NOT NULL,
    CONSTRAINT PK_RoomTagAssignment PRIMARY KEY (room_id, room_tag_id),
    CONSTRAINT FK_RTA_Room
        FOREIGN KEY (room_id)     REFERENCES dbo.Room(id),
    CONSTRAINT FK_RTA_Catalog
        FOREIGN KEY (room_tag_id) REFERENCES dbo.RoomTagCatalog(id)
);
GO

-- 4.11 AudioCall (session-level call data)
--      duration_seconds is a COMPUTED COLUMN (Requirement #1)
CREATE TABLE dbo.AudioCall (
    id                      INT             NOT NULL IDENTITY(1,1),
    room_id                 INT             NOT NULL,
    owner_user_id           INT             NOT NULL,
    provider_user_id        INT             NOT NULL,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'active',
    start_time              DATETIME        NOT NULL DEFAULT GETDATE(),
    end_time                DATETIME        NULL,
    -- COMPUTED COLUMN: auto-calculates call length in seconds
    duration_seconds
        AS dbo.fn_ComputeCallDuration(start_time, end_time),
    total_cost_tokens       INT             NOT NULL DEFAULT 0,
    artist_earnings_total   INT             NOT NULL DEFAULT 0,
    platform_earnings_total INT             NOT NULL DEFAULT 0,
    created_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_AudioCall PRIMARY KEY (id),
    CONSTRAINT FK_AudioCall_Room
        FOREIGN KEY (room_id)          REFERENCES dbo.Room(id),
    CONSTRAINT FK_AudioCall_Owner
        FOREIGN KEY (owner_user_id)    REFERENCES dbo.[User](id),
    CONSTRAINT FK_AudioCall_Provider
        FOREIGN KEY (provider_user_id) REFERENCES dbo.[User](id),
    CONSTRAINT CK_AudioCall_Status
        CHECK (status IN ('active', 'ended', 'missed', 'cancelled'))
);
GO

-- 4.12 AudioCallProvider (per-provider earnings per call)
--      artist_earn is a COMPUTED COLUMN (Requirement #1)
--      duration_seconds CHECK uses function (Requirement #2)
CREATE TABLE dbo.AudioCallProvider (
    audio_call_id    INT             NOT NULL,
    provider_id      INT             NOT NULL,
    price_tokens     INT             NOT NULL DEFAULT 0,
    duration_seconds INT             NULL,
    -- COMPUTED COLUMN: auto-calculates artist earnings after 20% platform fee
    artist_earn
        AS dbo.fn_ComputeArtistEarn(price_tokens, duration_seconds),
    joined_at        DATETIME        NOT NULL DEFAULT GETDATE(),
    left_at          DATETIME        NULL,
    created_at      DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at      DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_AudioCallProvider PRIMARY KEY (audio_call_id, provider_id),
    CONSTRAINT FK_ACP_Call
        FOREIGN KEY (audio_call_id) REFERENCES dbo.AudioCall(id),
    CONSTRAINT FK_ACP_Provider
        FOREIGN KEY (provider_id)   REFERENCES dbo.Provider(id),
    -- CHECK CONSTRAINT based on function (Requirement #2)
    CONSTRAINT CK_ACP_Duration
        CHECK (duration_seconds IS NULL OR dbo.fn_ValidateCallDuration(duration_seconds) = 1)
);
GO

-- 4.13 Tip (financial ledger for tips sent to providers)
--      tip_amount CHECK uses function (Requirement #2)
CREATE TABLE dbo.Tip (
    id              INT             NOT NULL IDENTITY(1,1),
    provider_id     INT             NOT NULL,
    sender_user_id  INT             NOT NULL,
    tip_type        VARCHAR(20)     NOT NULL DEFAULT 'coins',
    tip_amount_tokens INT           NOT NULL,
    created_at      DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_Tip PRIMARY KEY (id),
    CONSTRAINT FK_Tip_Provider
        FOREIGN KEY (provider_id)    REFERENCES dbo.Provider(id),
    CONSTRAINT FK_Tip_Sender
        FOREIGN KEY (sender_user_id) REFERENCES dbo.[User](id),
    -- CHECK CONSTRAINT based on function (Requirement #2)
    CONSTRAINT CK_Tip_Amount
        CHECK (dbo.fn_ValidateTipAmount(tip_amount_tokens) = 1),
    CONSTRAINT CK_Tip_Type
        CHECK (tip_type IN ('coins', 'gift', 'super_gift'))
);
GO

-- ============================================================
-- 5. INSERT DATA (>= 10 rows per table)
-- ============================================================

-- 5.1 Users (15 rows)
INSERT INTO dbo.[User] (name, email, email_verify_status, password, status, type, country_code, phone, phone_verify_status)
VALUES
    ('Alice Chen',    'alice@example.com',   1, 'hash_alice_001',   'active',    'user',  'US', '206-555-0101', 1),
    ('Bob Smith',     'bob@example.com',     1, 'hash_bob_002',     'active',    'user',  'US', '206-555-0102', 1),
    ('Carol Wu',      'carol@example.com',   1, 'hash_carol_003',   'active',    'user',  'CA', '206-555-0103', 1),
    ('David Kim',     'david@example.com',   1, 'hash_david_004',   'active',    'user',  'US', '206-555-0104', 0),
    ('Emma Patel',    'emma@example.com',    1, 'hash_emma_005',    'active',    'user',  'GB', '206-555-0105', 1),
    ('Frank Lee',     'frank@example.com',   1, 'hash_frank_006',   'active',    'user',  'US', '206-555-0106', 1),
    ('Grace Nguyen',  'grace@example.com',   0, 'hash_grace_007',   'active',    'user',  'VN', '206-555-0107', 0),
    ('Henry Brown',   'henry@example.com',   1, 'hash_henry_008',   'active',    'user',  'US', '206-555-0108', 1),
    ('Iris Zhang',    'iris@example.com',    1, 'hash_iris_009',    'active',    'user',  'CN', '206-555-0109', 1),
    ('Jack Wilson',   'jack@example.com',    1, 'hash_jack_010',    'suspended', 'user',  'US', '206-555-0110', 0),
    ('Kate Johnson',  'kate@example.com',    1, 'hash_kate_011',    'active',    'user',  'US', '206-555-0111', 1),
    ('Liam Davis',    'liam@example.com',    1, 'hash_liam_012',    'active',    'user',  'AU', '206-555-0112', 1),
    ('Mia Taylor',    'mia@example.com',     1, 'hash_mia_013',     'active',    'user',  'US', '206-555-0113', 1),
    ('Noah Martinez', 'noah@example.com',    0, 'hash_noah_014',    'active',    'user',  'MX', '206-555-0114', 0),
    ('Olivia White',  'olivia@example.com',  1, 'hash_olivia_015',  'active',    'admin', 'US', '206-555-0115', 1);
GO

-- 5.2 Members (10 rows – users 1–10)
INSERT INTO dbo.Member (user_id, nickname, token_balance, vip_level)
VALUES
    (1,  'AliceC',   500,  2),
    (2,  'BobS',     200,  1),
    (3,  'CarolW',   750,  3),
    (4,  'DavidK',   100,  1),
    (5,  'EmmaP',    300,  2),
    (6,  'FrankL',   50,   0),
    (7,  'GraceN',   0,    0),
    (8,  'HenryB',   1000, 4),
    (9,  'IrisZ',    450,  2),
    (10, 'JackW',    0,    0);
GO

-- 5.3 Providers (10 rows – users 6–15)
INSERT INTO dbo.Provider (user_id, display_name, service_type, bio, avatar_url, level, price, platform_fee_percentage, rating, total_minutes, is_available, is_verified)
VALUES
    (6,  'FrankTalks',    'coach',     'Life coach with 5 years experience.',       'https://cdn.example.com/frank.jpg',   3, 30, 20.00, 4.80, 320,  0, 1),
    (7,  'GraceHeals',    'wellness',  'Certified wellness consultant.',             'https://cdn.example.com/grace.jpg',   2, 25, 20.00, 4.60, 210,  1, 1),
    (8,  'HenryTeaches',  'tutor',     'Math and science tutor for all levels.',    'https://cdn.example.com/henry.jpg',   4, 20, 15.00, 4.90, 540,  1, 1),
    (9,  'IrisSings',     'entertain', 'Professional singer and vocal coach.',      'https://cdn.example.com/iris.jpg',    5, 35, 20.00, 4.95, 890,  1, 1),
    (10, 'JackCodes',     'tech',      'Senior software engineer, 10 yrs exp.',     'https://cdn.example.com/jack.jpg',    4, 40, 20.00, 4.70, 400,  0, 1),
    (11, 'KateWrites',    'creative',  'Published author and writing coach.',       'https://cdn.example.com/kate.jpg',    3, 28, 20.00, 4.75, 300,  1, 1),
    (12, 'LiamFit',       'fitness',   'Certified personal trainer.',               'https://cdn.example.com/liam.jpg',    2, 22, 20.00, 4.50, 180,  1, 0),
    (13, 'MiaDesigns',    'creative',  'UX/UI designer with 7 years experience.',   'https://cdn.example.com/mia.jpg',     4, 32, 20.00, 4.85, 460,  1, 1),
    (14, 'NoahSpeaks',    'coach',     'Public speaking and presentation coach.',   'https://cdn.example.com/noah.jpg',    3, 27, 20.00, 4.65, 270,  1, 1),
    (15, 'OliviaAdvises', 'finance',   'Chartered financial analyst.',              'https://cdn.example.com/olivia.jpg',  5, 45, 20.00, 4.92, 720,  1, 1);
GO

-- 5.4 Rooms (10 rows)
INSERT INTO dbo.Room (owner_user_id, name, description, is_group, service_fee, default_tip_amount, max_provider_count, status, service_type)
VALUES
    (1, 'Morning Motivation',        'Start your day with positive vibes.',         1, 0,  5,  5, 'active', 'public'),
    (2, 'Code & Coffee',             'Casual tech talk for developers.',             1, 0,  5,  3, 'active', 'public'),
    (3, 'Wellness Corner',           'Private wellness consultation room.',          0, 50, 10, 1, 'active', 'private'),
    (4, 'Math Help Desk',            'Open tutoring for STEM students.',             1, 0,  5,  4, 'active', 'public'),
    (5, 'Jazz Night Live',           'Live jazz performance room.',                  1, 20, 10, 2, 'active', 'premium'),
    (1, 'Career Coaching Circle',    'Professional career coaching sessions.',       1, 30, 10, 3, 'active', 'premium'),
    (2, 'Startup Pitch Practice',    'Practice and refine startup pitches.',         1, 0,  5,  5, 'active', 'public'),
    (3, 'Fitness Accountability',    'Track your fitness goals together.',           0, 40, 10, 1, 'active', 'private'),
    (4, 'Design Critique Studio',    'Portfolio review and design feedback.',        1, 0,  5,  4, 'active', 'public'),
    (5, 'Investment Talk',           'Discuss financial strategies.',                1, 50, 15, 3, 'active', 'premium');
GO

-- 5.5 RoomProvider (10 rows)
INSERT INTO dbo.RoomProvider (room_id, provider_id, user_id, status, tip_received, tip_amount, joined_at)
VALUES
    (1,  2,  7,  'active',   0, 0,   '2025-01-10 08:00:00'),
    (2,  5,  10, 'active',   1, 50,  '2025-01-10 09:00:00'),
    (3,  2,  7,  'inactive', 0, 0,   '2025-01-11 10:00:00'),
    (4,  3,  8,  'active',   1, 30,  '2025-01-12 11:00:00'),
    (5,  4,  9,  'active',   1, 100, '2025-01-13 19:00:00'),
    (6,  1,  6,  'active',   0, 0,   '2025-01-14 14:00:00'),
    (7,  9,  14, 'inactive', 0, 0,   '2025-01-15 16:00:00'),
    (8,  7,  12, 'active',   1, 40,  '2025-01-16 07:00:00'),
    (9,  8,  13, 'active',   1, 60,  '2025-01-17 13:00:00'),
    (10, 10, 15, 'active',   1, 80,  '2025-01-18 15:00:00');
GO

-- 5.6 RoomMessage (10 rows)
INSERT INTO dbo.RoomMessage (room_id, user_id, message, message_type, access)
VALUES
    (1, 1, 'Good morning everyone! Ready to get motivated?',  'text', 1),
    (1, 2, 'Let us do this! Great energy today.',             'text', 1),
    (2, 2, 'Anyone tried the new TypeScript 5 features?',     'text', 1),
    (2, 4, 'Yes, the const type parameters are great!',       'text', 1),
    (3, 3, 'Welcome to Wellness Corner.',                     'text', 1),
    (4, 4, 'Can someone explain matrix multiplication?',      'text', 1),
    (5, 5, 'The saxophone solo was incredible!',              'text', 1),
    (6, 1, 'What skills are most in demand right now?',       'text', 1),
    (9, 3, 'Love the new portfolio layout you shared!',       'text', 1),
    (10,5, 'What do you think about index funds in 2025?',    'text', 1);
GO

-- 5.7 ProviderTagCatalog (10 rows)
INSERT INTO dbo.ProviderTagCatalog (name, display_name, category, color, sort_order, is_active)
VALUES
    ('life_coaching',    'Life Coaching',    'coaching',     '#FF6B6B', 1,  1),
    ('wellness',         'Wellness',         'health',       '#4ECDC4', 2,  1),
    ('tutoring',         'Academic Tutor',   'education',    '#45B7D1', 3,  1),
    ('music',            'Music',            'entertainment','#96CEB4', 4,  1),
    ('technology',       'Technology',       'tech',         '#88D8B0', 5,  1),
    ('creative_writing', 'Creative Writing', 'creative',     '#FFEAA7', 6,  1),
    ('fitness',          'Fitness',          'health',       '#DDA0DD', 7,  1),
    ('ux_design',        'UX Design',        'creative',     '#F0E68C', 8,  1),
    ('public_speaking',  'Public Speaking',  'coaching',     '#FFB6C1', 9,  1),
    ('finance',          'Finance',          'business',     '#B0C4DE', 10, 1);
GO

-- 5.8 ProviderTagAssignment (10 rows)
INSERT INTO dbo.ProviderTagAssignment (tag_id, provider_id)
VALUES
    (1,  1),   -- FrankTalks: Life Coaching
    (2,  2),   -- GraceHeals: Wellness
    (3,  3),   -- HenryTeaches: Tutoring
    (4,  4),   -- IrisSings: Music
    (5,  5),   -- JackCodes: Technology
    (6,  6),   -- KateWrites: Creative Writing
    (7,  7),   -- LiamFit: Fitness
    (8,  8),   -- MiaDesigns: UX Design
    (9,  9),   -- NoahSpeaks: Public Speaking
    (10, 10);  -- OliviaAdvises: Finance
GO

-- 5.9 RoomTagCatalog (10 rows)
INSERT INTO dbo.RoomTagCatalog (name)
VALUES
    ('Motivation'),
    ('Technology'),
    ('Wellness'),
    ('Education'),
    ('Music & Arts'),
    ('Career'),
    ('Entrepreneurship'),
    ('Fitness'),
    ('Design'),
    ('Finance');
GO

-- 5.10 RoomTagAssignment (10 rows)
INSERT INTO dbo.RoomTagAssignment (room_id, room_tag_id)
VALUES
    (1,  1),
    (2,  2),
    (3,  3),
    (4,  4),
    (5,  5),
    (6,  6),
    (7,  7),
    (8,  8),
    (9,  9),
    (10, 10);
GO

-- 5.11 AudioCall (10 rows)
INSERT INTO dbo.AudioCall (room_id, owner_user_id, provider_user_id, status, start_time, end_time, total_cost_tokens, artist_earnings_total, platform_earnings_total)
VALUES
    (1,  1, 7,  'ended',     '2025-01-10 08:05:00', '2025-01-10 08:35:00', 900,  720,  180),
    (2,  2, 10, 'ended',     '2025-01-10 09:10:00', '2025-01-10 09:55:00', 1800, 1440, 360),
    (3,  3, 7,  'ended',     '2025-01-11 10:15:00', '2025-01-11 10:45:00', 750,  600,  150),
    (4,  4, 8,  'ended',     '2025-01-12 11:20:00', '2025-01-12 12:00:00', 680,  578,  102),
    (5,  5, 9,  'ended',     '2025-01-13 19:05:00', '2025-01-13 19:50:00', 1575, 1260, 315),
    (6,  1, 6,  'ended',     '2025-01-14 14:10:00', '2025-01-14 15:00:00', 1500, 1200, 300),
    (7,  2, 14, 'cancelled', '2025-01-15 16:05:00', NULL,                  0,    0,    0),
    (8,  3, 12, 'ended',     '2025-01-16 07:15:00', '2025-01-16 07:45:00', 660,  528,  132),
    (9,  4, 13, 'ended',     '2025-01-17 13:10:00', '2025-01-17 14:10:00', 1920, 1536, 384),
    (10, 5, 15, 'ended',     '2025-01-18 15:05:00', '2025-01-18 16:05:00', 2700, 2160, 540);
GO

-- 5.12 AudioCallProvider (10 rows)
INSERT INTO dbo.AudioCallProvider (audio_call_id, provider_id, price_tokens, joined_at, left_at, duration_seconds)
VALUES
    (1,  2,  30, '2025-01-10 08:05:00', '2025-01-10 08:35:00', 1800),
    (2,  5,  40, '2025-01-10 09:10:00', '2025-01-10 09:55:00', 2700),
    (3,  2,  25, '2025-01-11 10:15:00', '2025-01-11 10:45:00', 1800),
    (4,  3,  20, '2025-01-12 11:20:00', '2025-01-12 12:00:00', 2400),
    (5,  4,  35, '2025-01-13 19:05:00', '2025-01-13 19:50:00', 2700),
    (6,  1,  30, '2025-01-14 14:10:00', '2025-01-14 15:00:00', 3000),
    (8,  7,  22, '2025-01-16 07:15:00', '2025-01-16 07:45:00', 1800),
    (9,  8,  32, '2025-01-17 13:10:00', '2025-01-17 14:10:00', 3600),
    (10, 10, 45, '2025-01-18 15:05:00', '2025-01-18 16:05:00', 3600),
    (2,  3,  20, '2025-01-10 09:10:00', '2025-01-10 09:55:00', 2700);
GO

-- 5.13 Tip (10 rows)
INSERT INTO dbo.Tip (provider_id, sender_user_id, tip_type, tip_amount_tokens)
VALUES
    (2,  1, 'coins',      50),
    (5,  2, 'coins',      100),
    (2,  3, 'gift',       35),
    (3,  4, 'coins',      70),
    (4,  5, 'gift',       150),
    (1,  1, 'coins',      80),
    (7,  2, 'coins',      45),
    (8,  3, 'super_gift', 200),
    (10, 5, 'coins',      300),
    (9,  4, 'gift',       120);
GO

-- ============================================================
-- 6. VIEWS (3 views)
-- ============================================================

-- VIEW 1: Provider Earnings Summary
--   Total call earnings + tips per provider. For financial reporting.
IF OBJECT_ID('dbo.vw_ProviderEarningsSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ProviderEarningsSummary;
GO
CREATE VIEW dbo.vw_ProviderEarningsSummary AS
SELECT
    p.id                                            AS provider_id,
    u.name                                          AS provider_name,
    p.service_type,
    p.rating,
    COUNT(DISTINCT acp.audio_call_id)               AS total_calls,
    COALESCE(SUM(acp.duration_seconds) / 60, 0)     AS total_call_minutes,
    COALESCE(SUM(acp.price_tokens * acp.duration_seconds / 60
        * (1 - p.platform_fee_percentage / 100.0)), 0) AS total_call_earnings,
    COALESCE(SUM(t.tip_amount_tokens), 0)           AS total_tips_received,
    COALESCE(SUM(acp.price_tokens * acp.duration_seconds / 60
        * (1 - p.platform_fee_percentage / 100.0)), 0)
        + COALESCE(SUM(t.tip_amount_tokens), 0)     AS grand_total_earnings
FROM dbo.Provider p
JOIN dbo.[User] u
    ON p.user_id = u.id
LEFT JOIN dbo.AudioCallProvider acp
    ON p.id = acp.provider_id
LEFT JOIN dbo.Tip t
    ON p.id = t.provider_id
GROUP BY
    p.id, u.name, p.service_type, p.rating, p.platform_fee_percentage;
GO

-- VIEW 2: Active Room Overview
--   Room details with provider count, message count, tags. For dashboard.
IF OBJECT_ID('dbo.vw_ActiveRoomOverview', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ActiveRoomOverview;
GO
CREATE VIEW dbo.vw_ActiveRoomOverview AS
SELECT
    r.id                                            AS room_id,
    r.name                                          AS room_name,
    r.service_type,
    u.name                                          AS owner_name,
    r.max_provider_count,
    COUNT(DISTINCT rp.provider_id)                  AS active_provider_count,
    COUNT(DISTINCT rm.message_id)                   AS total_messages,
    (SELECT STRING_AGG(rtc2.name, ', ')
     FROM dbo.RoomTagAssignment rta2
     JOIN dbo.RoomTagCatalog rtc2 ON rta2.room_tag_id = rtc2.id
     WHERE rta2.room_id = r.id)                     AS room_tags,
    r.created_at
FROM dbo.Room r
JOIN dbo.[User] u
    ON r.owner_user_id = u.id
LEFT JOIN dbo.RoomProvider rp
    ON r.id = rp.room_id AND rp.status = 'active'
LEFT JOIN dbo.RoomMessage rm
    ON r.id = rm.room_id AND rm.deleted_at IS NULL
WHERE r.status = 'active'
GROUP BY
    r.id, r.name, r.service_type, u.name, r.max_provider_count, r.created_at;
GO

-- VIEW 3: Member Room Activity Summary
--   Combines member spending with room ownership stats. For BI reporting.
IF OBJECT_ID('dbo.vw_MemberRoomActivitySummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_MemberRoomActivitySummary;
GO

CREATE VIEW dbo.vw_MemberRoomActivitySummary AS
WITH MemberSpend AS (
    SELECT
        u.id AS user_id,
        u.name AS member_name,
        m.vip_level,
        m.token_balance,
        COUNT(DISTINCT ac.id) AS total_calls_made,
        COALESCE(SUM(ac.total_cost_tokens), 0) AS total_tokens_spent_on_calls,
        COALESCE(SUM(t.tip_amount_tokens), 0) AS total_tokens_spent_on_tips,
        COALESCE(SUM(ac.total_cost_tokens), 0) + COALESCE(SUM(t.tip_amount_tokens), 0) AS total_tokens_spent
    FROM dbo.Member m
    JOIN dbo.[User] u
        ON m.user_id = u.id
    LEFT JOIN dbo.AudioCall ac
        ON u.id = ac.owner_user_id
    LEFT JOIN dbo.Tip t
        ON u.id = t.sender_user_id
    GROUP BY u.id, u.name, m.vip_level, m.token_balance
),
RoomStats AS (
    SELECT
        r.owner_user_id AS user_id,
        COUNT(DISTINCT r.id) AS total_rooms_owned,
        COUNT(DISTINCT CASE WHEN r.status = 'active' THEN r.id END) AS active_rooms_owned,
        COUNT(DISTINCT rm.message_id) AS total_messages_in_rooms,
        COUNT(DISTINCT rp.provider_id) AS total_active_providers_in_rooms
    FROM dbo.Room r
    LEFT JOIN dbo.RoomMessage rm
        ON r.id = rm.room_id AND rm.deleted_at IS NULL
    LEFT JOIN dbo.RoomProvider rp
        ON r.id = rp.room_id AND rp.status = 'active'
    GROUP BY r.owner_user_id
)
SELECT
    ms.user_id,
    ms.member_name,
    ms.vip_level,
    ms.token_balance,
    ms.total_calls_made,
    ms.total_tokens_spent_on_calls,
    ms.total_tokens_spent_on_tips,
    ms.total_tokens_spent,
    COALESCE(rs.total_rooms_owned, 0) AS total_rooms_owned,
    COALESCE(rs.active_rooms_owned, 0) AS active_rooms_owned,
    COALESCE(rs.total_messages_in_rooms, 0) AS total_messages_in_rooms,
    COALESCE(rs.total_active_providers_in_rooms, 0) AS total_active_providers_in_rooms
FROM MemberSpend ms
LEFT JOIN RoomStats rs
    ON ms.user_id = rs.user_id;
GO

-- ============================================================
-- 7. VERIFICATION QUERIES
-- ============================================================

-- Row counts per table
SELECT 'User'                  AS tbl, COUNT(*) AS rows FROM dbo.[User]               UNION ALL
SELECT 'Member',                        COUNT(*) FROM dbo.Member                       UNION ALL
SELECT 'Provider',                      COUNT(*) FROM dbo.Provider                     UNION ALL
SELECT 'Room',                          COUNT(*) FROM dbo.Room                         UNION ALL
SELECT 'RoomProvider',                  COUNT(*) FROM dbo.RoomProvider                 UNION ALL
SELECT 'RoomMessage',                   COUNT(*) FROM dbo.RoomMessage                  UNION ALL
SELECT 'ProviderTagCatalog',            COUNT(*) FROM dbo.ProviderTagCatalog           UNION ALL
SELECT 'ProviderTagAssignment',         COUNT(*) FROM dbo.ProviderTagAssignment        UNION ALL
SELECT 'RoomTagCatalog',                COUNT(*) FROM dbo.RoomTagCatalog               UNION ALL
SELECT 'RoomTagAssignment',             COUNT(*) FROM dbo.RoomTagAssignment            UNION ALL
SELECT 'AudioCall',                     COUNT(*) FROM dbo.AudioCall                    UNION ALL
SELECT 'AudioCallProvider',             COUNT(*) FROM dbo.AudioCallProvider            UNION ALL
SELECT 'Tip',                           COUNT(*) FROM dbo.Tip;

-- Verify computed column: call duration
SELECT id, start_time, end_time, duration_seconds
FROM dbo.AudioCall
WHERE end_time IS NOT NULL;

-- Preview views
SELECT * FROM dbo.vw_ProviderEarningsSummary  ORDER BY grand_total_earnings DESC;
SELECT * FROM dbo.vw_ActiveRoomOverview        ORDER BY room_id;
SELECT * FROM dbo.vw_MemberRoomActivitySummary     ORDER BY total_tokens_spent DESC;
GO
