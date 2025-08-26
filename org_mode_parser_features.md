Org-Mode Parser Feature List
Outline Structure and Headings

Headline Hierarchy: Org-mode files are organized as an outline. Headings start with one or more asterisks (*) at the left margin, defining levels in a hierarchical tree
orgmode.org
. For example, * marks a top-level heading, ** a second-level subheading, and so on. The parser must detect these headline levels to recreate the tree structure of the document. Headings are not numbered by default (numbering can be enabled dynamically)
orgmode.org
. Each heading contains the title text of the entry.

Headline Metadata (TODO, Priority, Tags): A heading line can include metadata like TODO keywords, priority markers, and tags. For example: ** TODO [#A] Finish report :work:urgent: is a second-level heading with a TODO state “TODO”, highest priority A, and tags “work” and “urgent”. The parser should identify TODO keywords at the start of the headline (if present), priority cookies in the form [#X] right after the TODO keyword
orgmode.org
, and tags which appear at the end of the headline enclosed in colons
orgmode.org
. These components are crucial for task management and filtering. A heading may have none or all of these components. (See below for details on TODO states, priorities, and tags.)

Sections and Content: Content under a heading (up until the next heading of equal or higher level) is the body or section of that headline. The parser must group text, lists, blocks, etc. under the correct parent headline. Also note that an entry ends where a less-indented or equal-indented headline begins. Blank lines can separate paragraphs in a section and are considered part of the section content by convention
orgmode.org
.

TODO Items and Workflow States

TODO States: Org allows headings to be marked as actionable TODO items. Any headline that begins with a TODO keyword (like TODO, DONE, or user-defined keywords) is considered a todo item
orgmode.org
. The parser should detect these keywords at the start of headline titles. Org-mode supports customizable workflows: sequences of TODO keywords (e.g. TODO → FEEDBACK → VERIFY → DONE) with the | divider separating active states from completed states
orgmode.org
. The parser should be able to capture the TODO keyword of each headline and whether it represents an open state or a closed (done) state. It should also support multiple TODO state sets in a file (defined by #+TODO: or #+SEQ_TODO: lines for file-local workflows
orgmode.org
).

Keyword Cycling: In Emacs Org, pressing C-c C-t cycles a headline through its TODO states
orgmode.org
. While a parser doesn’t perform interactive cycling, it should represent the list of possible states for each item (especially if using custom keywords) so that a client application can cycle or change states according to the same sequence. The parser might load global or file-defined TODO keywords (from in-buffer settings) so it knows all valid states and which are considered “done” states
orgmode.org
.

Todo Dependencies and Sequence Tracking: (Optional) Org can enforce TODO dependencies (e.g., not allowing a task to be DONE if subtasks are not DONE)
orgmode.org
. While this is more behavior than syntax, a full-featured parser could note relationships like parent/child TODO status. This is not strictly required for parsing, but it ties into agenda views (e.g., “stuck projects” are those with a TODO parent and no progress in children).

Tags and Priorities

Tags: Tags are user-defined keywords that categorize headlines. In the Org syntax, tags appear at the end of a headline, enclosed in colons, for example ** Plan the trip :travel:urgent:. The parser should extract any tags on a headline (potentially multiple tags)
orgmode.org
. Tags can inherit down the hierarchy (by default, a child headline inherits the tags of its ancestors unless configured otherwise), so the parser may also need to provide means to compute an entry’s effective tags (if the application uses tag inheritance). Additionally, file-wide tags can be set with a #+FILETAGS: line, which the parser should apply to all entries in that file
orgmode.org
.

Priorities: Org-mode supports priority cookies on headlines to indicate relative importance. These are single characters like A, B, C (or numerals) shown in square brackets after the TODO keyword. For example, [#A] in a heading denotes highest priority
orgmode.org
. The parser should detect if a headline contains a priority cookie, capture its value, and know the global or file-defined range of priority values (default A through C, where A is highest)
orgmode.org
. If no priority is given on a headline, it is treated as the default (e.g. B by default)
orgmode.org
. Priorities primarily matter for sorting in agenda views
orgmode.org
. A #+PRIORITIES: A C B line can redefine the highest, lowest, and default priority in a file, which the parser should recognize
orgmode.org
.

Planning and Scheduling (Timestamps & Deadlines)

Timestamps: Org timestamps represent dates and times and are written in a specific format: YYYY-MM-DD Day with optional time or time range, e.g. <2025-08-26 Tue> or <2025-08-26 Tue 09:00-11:00>
orgmode.org
orgmode.org
. Active timestamps use < > and inactive timestamps use [ ]. The parser should recognize timestamps in either form. An active timestamp in a heading or entry means that item will appear on the agenda for that date (as an appointment or event)
orgmode.org
, whereas an inactive timestamp (in square brackets) is for record-keeping and does not cause an agenda entry
orgmode.org
. Timestamps may also include repeater intervals (e.g. <2025-08-26 Tue +1w> for weekly recurrence) or special diary sexp expressions <%%(...)> for complex repeats
orgmode.org
orgmode.org
 – the parser should capture the literal string including these so that recurrence can be computed by the application.

Scheduled & Deadline: Org-mode provides special planning keywords that appear on a line directly below a headline to schedule tasks. A line starting with SCHEDULED: or DEADLINE: followed by an active timestamp assigns a planned date
orgmode.org
. SCHEDULED:<date> indicates when work on the task is intended to start, and DEADLINE:<date> indicates when the task is due
orgmode.org
orgmode.org
. The parser needs to detect these planning lines and associate the timestamp with the task’s scheduling metadata. Both may appear, along with a CLOSED: timestamp (when the task was finished) in the “planning section” immediately after a headline. For example:
