-- -----------------------------------------------------
-- Schema: VoiceCallPlatform
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `VoiceCallPlatform` DEFAULT CHARACTER SET utf8mb4 ;
USE `VoiceCallPlatform` ;

-- 1. User: 核心身份 [cite: 14]
CREATE TABLE IF NOT EXISTS `User` (
  `user_id` INT NOT NULL AUTO_INCREMENT, -- [PK]
  `email` VARCHAR(255) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `verification_status` VARCHAR(50) NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE INDEX `ux_user_email` (`email` ASC))
ENGINE = InnoDB;

-- 2. Member: 用户角色扩展 [cite: 15]
CREATE TABLE IF NOT EXISTS `Member` (
  `member_id` INT NOT NULL AUTO_INCREMENT, -- [PK]
  `user_id` INT NOT NULL, -- [FK] [cite: 30]
  `nickname` VARCHAR(100) NULL,
  PRIMARY KEY (`member_id`),
  UNIQUE INDEX `ux_member_user_id` (`user_id` ASC),
  CONSTRAINT `fk_member_user`
    FOREIGN KEY (`user_id`)
    REFERENCES `User` (`user_id`))
ENGINE = InnoDB;

-- 3. Provider: 提供者角色扩展 [cite: 16]
CREATE TABLE IF NOT EXISTS `Provider` (
  `provider_id` INT NOT NULL AUTO_INCREMENT, -- [PK]
  `user_id` INT NOT NULL, -- [FK] [cite: 33]
  `biography` TEXT NULL,
  `service_information` TEXT NULL,
  PRIMARY KEY (`provider_id`),
  UNIQUE INDEX `ux_provider_user_id` (`user_id` ASC),
  CONSTRAINT `fk_provider_user`
    FOREIGN KEY (`user_id`)
    REFERENCES `User` (`user_id`))
ENGINE = InnoDB;

-- 4. Room: 房间 [cite: 17]
CREATE TABLE IF NOT EXISTS `Room` (
  `room_id` INT NOT NULL AUTO_INCREMENT, -- [PK]
  `owner_user_id` INT NOT NULL, -- [FK] [cite: 36]
  `title` VARCHAR(200) NULL,
  `room_type` ENUM('1-on-1', 'group') NULL,
  PRIMARY KEY (`room_id`),
  CONSTRAINT `fk_room_user_owner`
    FOREIGN KEY (`owner_user_id`)
    REFERENCES `User` (`user_id`))
ENGINE = InnoDB;

-- 5. RoomProvider: 房间与提供者关联 (识别性关系) [cite: 18, 39]
CREATE TABLE IF NOT EXISTS `RoomProvider` (
  `room_id` INT NOT NULL, -- [PK, FK]
  `provider_id` INT NOT NULL, -- [PK, FK]
  `participation_status` VARCHAR(50) NULL,
  `joined_at` DATETIME NULL,
  PRIMARY KEY (`room_id`, `provider_id`), -- [Composite PK]
  CONSTRAINT `fk_room_provider_room`
    FOREIGN KEY (`room_id`)
    REFERENCES `Room` (`room_id`),
  CONSTRAINT `fk_room_provider_provider`
    FOREIGN KEY (`provider_id`)
    REFERENCES `Provider` (`provider_id`))
ENGINE = InnoDB;

-- 6. RoomMessage: 房间消息 [cite: 19]
CREATE TABLE IF NOT EXISTS `RoomMessage` (
  `message_id` INT NOT NULL AUTO_INCREMENT, -- [PK]
  `room_id` INT NOT NULL, -- [FK] [cite: 42]
  `sender_user_id` INT NOT NULL, -- [FK] [cite: 43]
  `message_content` TEXT NULL,
  `message_type` VARCHAR(50) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`message_id`),
  CONSTRAINT `fk_room_message_room`
    FOREIGN KEY (`room_id`)
    REFERENCES `Room` (`room_id`),
  CONSTRAINT `fk_room_message_user`
    FOREIGN KEY (`sender_user_id`)
    REFERENCES `User` (`user_id`))
ENGINE = InnoDB;

-- 7. AudioCall: 通话记录 [cite: 20]
CREATE TABLE IF NOT EXISTS `AudioCall` (
  `audio_call_id` INT NOT NULL AUTO_INCREMENT, -- [PK]
  `room_id` INT NOT NULL, -- [FK] [cite: 47]
  `start_time` DATETIME NULL,
  `end_time` DATETIME NULL,
  `call_status` VARCHAR(50) NULL,
  PRIMARY KEY (`audio_call_id`),
  CONSTRAINT `fk_audio_call_room`
    FOREIGN KEY (`room_id`)
    REFERENCES `Room` (`room_id`))
ENGINE = InnoDB;

-- 8. AudioCallProvider: 通话结算 (识别性关系) [cite: 21, 51]
CREATE TABLE IF NOT EXISTS `AudioCallProvider` (
  `audio_call_id` INT NOT NULL, -- [PK, FK]
  `provider_id` INT NOT NULL, -- [PK, FK]
  `total_earnings` DECIMAL(10, 2) NULL,
  `duration_in_seconds` INT NULL,
  PRIMARY KEY (`audio_call_id`, `provider_id`), -- [Composite PK]
  CONSTRAINT `fk_call_provider_call`
    FOREIGN KEY (`audio_call_id`)
    REFERENCES `AudioCall` (`audio_call_id`),
  CONSTRAINT `fk_call_provider_provider`
    FOREIGN KEY (`provider_id`)
    REFERENCES `Provider` (`provider_id`))
ENGINE = InnoDB;

-- 9. Tip: 打赏账本 [cite: 22, 79]
CREATE TABLE IF NOT EXISTS `Tip` (
  `tip_id` INT NOT NULL AUTO_INCREMENT, -- [PK]
  `provider_id` INT NOT NULL, -- [FK] [cite: 54]
  `sender_user_id` INT NOT NULL, -- [FK]
  `tip_amount` DECIMAL(10, 2) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`tip_id`),
  CONSTRAINT `fk_tip_provider`
    FOREIGN KEY (`provider_id`)
    REFERENCES `Provider` (`provider_id`),
  CONSTRAINT `fk_tip_user_sender`
    FOREIGN KEY (`sender_user_id`)
    REFERENCES `User` (`user_id`))
ENGINE = InnoDB;

-- 10. ProviderTagCatalog: 标签库 [cite: 23]
CREATE TABLE IF NOT EXISTS `ProviderTagCatalog` (
  `provider_tag_id` INT NOT NULL AUTO_INCREMENT, -- [PK]
  `tag_name` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`provider_tag_id`),
  UNIQUE INDEX `ux_provider_tag_name` (`tag_name` ASC))
ENGINE = InnoDB;

-- 11. ProviderTagAssignment: 解决 M:N [cite: 24, 57]
CREATE TABLE IF NOT EXISTS `ProviderTagAssignment` (
  `provider_id` INT NOT NULL, -- [PK, FK]
  `provider_tag_id` INT NOT NULL, -- [PK, FK]
  PRIMARY KEY (`provider_id`, `provider_tag_id`), -- [Composite PK]
  CONSTRAINT `fk_tag_assign_provider`
    FOREIGN KEY (`provider_id`)
    REFERENCES `Provider` (`provider_id`),
  CONSTRAINT `fk_tag_assign_catalog`
    FOREIGN KEY (`provider_tag_id`)
    REFERENCES `ProviderTagCatalog` (`provider_tag_id`))
ENGINE = InnoDB;

-- 12. RoomTagCatalog: 房间标签库 [cite: 25]
CREATE TABLE IF NOT EXISTS `RoomTagCatalog` (
  `room_tag_id` INT NOT NULL AUTO_INCREMENT, -- [PK]
  `tag_name` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`room_tag_id`),
  UNIQUE INDEX `ux_room_tag_name` (`tag_name` ASC))
ENGINE = InnoDB;

-- 13. RoomTagAssignment: 解决 M:N [cite: 26, 61]
CREATE TABLE IF NOT EXISTS `RoomTagAssignment` (
  `room_id` INT NOT NULL, -- [PK, FK]
  `room_tag_id` INT NOT NULL, -- [PK, FK]
  PRIMARY KEY (`room_id`, `room_tag_id`), -- [Composite PK]
  CONSTRAINT `fk_room_tag_assign_room`
    FOREIGN KEY (`room_id`)
    REFERENCES `Room` (`room_id`),
  CONSTRAINT `fk_room_tag_assign_catalog`
    FOREIGN KEY (`room_tag_id`)
    REFERENCES `RoomTagCatalog` (`room_tag_id`))
ENGINE = InnoDB;
