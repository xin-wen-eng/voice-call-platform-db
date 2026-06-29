Phase 2: Database Design and Initial ERD
Team Number: Team 3
Database Topic: Voice-Call Chat & Social Interaction Platform Database

1. Overview / Business Problems
This database supports an audio-call platform addressing these core needs:
•	Role Management: Separate authentication from user roles (Member/Provider) to avoid redundancy.
•	Participation Tracking: Manage room creation and track provider participation.
•	Monetization & Reporting: Record audio call sessions, provider earnings, and user tips for financial auditing.
•	Searchability: Categorize providers and rooms via a standardized tagging system.
2. Entities (12+ required) and Purpose 
•	User: Core identity and authentication.
•	Member: Role extension for general users.
•	Provider: Role extension for service providers.
•	Room: Represents a chat or call session environment.
•	RoomProvider: Junction table tracking providers in rooms.
•	RoomMessage: Stores text/media messages sent within rooms.
•	AudioCall: Records session-level call data.
•	AudioCallProvider: Junction table for per-provider earnings and duration.
•	Tip: Ledger for financial tips sent to providers.
•	ProviderTagCatalog: Predefined library of provider tags.
•	ProviderTagAssignment: Junction table mapping tags to providers.
•	RoomTagCatalog: Predefined library of room categories.
•	RoomTagAssignment: Junction table mapping tags to rooms.
3. Relationships (Cardinality, Participation & Identifying Type)
A) Non-Identifying Relationships (8 Dashed Lines in ERD)
These relationships connect independent entities where the child entity has its own primary key. The relationship is Optional (indicated by a circle ○) on the child side.
•	User ↔ Member: (1:0..1) Non-identifying. Parent (User) is Mandatory (||); Child (Member) is Optional (○|). 
•	User ↔ Provider: (1:0..1) Non-identifying. Parent (User) is Mandatory (||); Child (Provider) is Optional (○|). 
•	User ↔ Room: (1:0..M) Non-identifying. One User (Owner) is Mandatory (||) for many Rooms (○<). 
•	User ↔ RoomMessage: (1:0..M) Non-identifying. One User (Sender) is Mandatory (||) for many Messages (○<). 
•	Room ↔ RoomMessage: (1:0..M) Non-identifying. One Room is Mandatory (||) for many Messages (○<). Although messages are created within a room, we use a Non-identifying relationship. This ensures that the message records (which have their own message_id) can be preserved independently for compliance and safety auditing even if the physical room container is closed or removed.
•	Room ↔ AudioCall: (1:0..M) Non-identifying. One Room is Mandatory (||) for many Calls (○<). This is a deliberate financial decision: even if a chat room is closed, the call records and billing data in AudioCallProvider must be preserved for long-term financial auditing and provider payout history.
•	Provider ↔ Tip: (1:0..M) Non-identifying. One Provider (Receiver) is Mandatory (||) for many Tips (○<). (Note: Tip also connects to User as the sender via a non-identifying dashed line )
B) Identifying Relationships (8 Solid Lines in ERD)
These relationships connect parent entities to junction tables. The child entity uses a Composite Primary Key and is existence-dependent on the parent.
•	Room ↔ RoomProvider: (1:0..M) Identifying. Mandatory parent (||) to Optional many (○<). 
•	Provider ↔ RoomProvider: (1:0..M) Identifying. Mandatory parent (||) to Optional many (○<). 
•	AudioCall ↔ AudioCallProvider: (1:0..M) Identifying. Mandatory parent (||) to Optional many (○<). 
•	Provider ↔ AudioCallProvider: (1:0..M) Identifying. Mandatory parent (||) to Optional many (○<). 
•	Provider ↔ ProviderTagAssignment: (1:0..M) Identifying. Resolves M:N relationship with Mandatory parent. 
•	ProviderTagCatalog ↔ ProviderTagAssignment: (1:0..M) Identifying. Resolves M:N relationship with Mandatory parent. 
•	Room ↔ RoomTagAssignment: (1:0..M) Identifying. Resolves M:N relationship with Mandatory parent. 
•	RoomTagCatalog ↔ RoomTagAssignment: (1:0..M) Identifying. Resolves M:N relationship with Mandatory parent. 
4. Normalization and ERD Quality (3NF)
•	No Multi-valued Attributes: Handled by ProviderTagAssignment and RoomTagAssignment.
•	No Repeating Groups: No tag1/tag2 columns; all tags are stored in separate catalog tables.
•	No Many-to-Many Relationships: All resolved via the 8 identifying relationships mentioned above.
•	Cardinality Check: All lines show two symbols at each end: a circle/bar for participation and a bar/crow’s foot for cardinality, as required by Rubric 2.
5. Key Design Decisions
•	Specialization (User/Member/Provider): Reduces data duplication and allows users to hold multiple roles.
•	Junction Entities for Metadata: RoomProvider and AudioCallProvider store data specific to the interaction (e.g., earnings, duration) rather than the individual entity.
•	Standardized Tagging: Using Catalog tables ensures data integrity and supports efficient filtering for Business Intelligence (BI) reporting.
•	Standalone Tipping Ledger: Ensures financial transactions are immutable and easily auditable.

<img width="468" height="645" alt="image" src="https://github.com/user-attachments/assets/f1912500-b49c-4642-9472-4c45fa540bdd" />
