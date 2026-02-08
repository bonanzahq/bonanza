# README

## TODOs

### Core Features & Bug Fixes
- [ ] Roles and rights -> check if all working
  - [ ] admin
  - [ ] leader
  - [ ] member
  - [x] guest -> DONE, all good
- [ ] Turn item_history into "history" for every borrow
  - [ ] event_type: lending, return, warning, ban, registered, accepted_tos
  - [ ] BUG: when returning blank history entry is created ?
- [ ] **parent item should not be changed**
  - [ ] if child is lent, accessories should not be changed
- [ ] **item**
  - [ ] if item is lent, you should only be able to change its note

### UI Improvements
- [ ] Add read-more / read-less link to department describtions
- [ ] add 'archived items' to verwaltung

### User Management
- [ ] Allow deleting of users

### Email Notifications
- [ ] enable email notifications for borrowers
  - [ ] genderize departments in emails
- [ ] enable emails for lendings
  - [ ] confirmation_email
  - [ ] overdue_notification_email
  - [ ] upcoming_return_notification_email
  - [ ] department_unstaffed_notification_email
  - [ ] department_staffed_again_notification_email
  - [ ] duration_change_notification_email
  - [ ] Add .ics to Email (and issue update if lendig date is changed)
- [ ] enable emails for user (not guest, not hidden!)
  - [ ] todays returns email
- [ ] change email template of devise emails to new template
  - [ ] email_changed
  - [ ] password_change
  - [ ] reset_pw_instructions
  - [ ] unlock_instructions
  - [ ] check new invitation_instructions email template

### Warning & Banning
- [ ] **Warning & Banning**
  - [ ] 2 x warning -> note & email
  - [ ] 1 x warning? -> note & email
  - [ ] Implement Borrower suspension & lifting of suspension

### Department Management
- [ ] "vorübergehend schließen" feature
  - [ ] check if email notification for active borrowers is working

### TOS & Data Privacy
- [ ] **tos & data privacy**
  - [ ] notify borrowers of changes via email?
  - [ ] require new acceptance ?
  - [ ] remove students after x months after last activity

### Item Management
- [ ] **Deleting of items:**
  - [ ] if item is not lent
    - [ ] delete item ?
      - [ ] delete item history
    - [ ] or archive item?
- [ ] **Deleting of parent items:**
  - [ ] archive item?
  - [ ] archived item -> delete permanently

### GDPR Compliance
- [ ] GDPR
  - [ ] auto delete after x months? -> reactivate/keep alive account via link in email?
  - [ ] delete borrowers that did not finish registration after 14 days

### Data Migration
- [ ] Come up with Migration Strategy
  - [ ] map old tables to new tables & fields
  - [ ] old bonanza:
    - [ ] migrate db to new state
    - [ ] us pgloader to move data from mysql to postgres
  - [ ] get back up, change sql file, import data into new structure

### Build & Deploy
- [ ] Add PurgeCSS before precompiling assets

## Server & Deploy
- nginx & PUMA as server https://github.com/puma/puma/blob/master/docs/systemd.md
- elasticsearch 8.7 + temurin jdk 17 -> add env for external elasticsearch.yml and jvm.options
- run rails turbo:install after turbo_rails update

**copy es_synonyms.txt to elasticsearch config folder**

**add default template for indices**

```
curl --cacert /Users/philipp/elasticsearch-8.4.3/config/certs/http_ca.crt -u elastic -XPUT "https://localhost:9200/_template/default_template" -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["*"],
  "settings": {
    "index": {
      "number_of_replicas": 0,
      "number_of_shards": 1
    }
  }
}'
```

- bundle lock to x86_64-linux: bundle lock --add-platform x86_64-linux (NOTE: unclear if still relevant!)


## General Features
- TOS that can be edited by any manager
- Data Privacy statement that can be edited by any manager
- Editable common pages
- Hide Test Department


### Roles & Rights
Admin
  Every user can be admin. The role is complementary and extends the rights of the assigned roles per department

Leader
  Can send invites to externals to become users of their department
  Leader can assign change roles of users for their department

Member
  Can handle lending and returns
  Can manage data of borrowers

Guest
  viewer-only rights in their department
  can be seen by members of the department, but not public

Hidden
  viewer-only rights in their department
  "hidden" can only be seen by admins

### Invitations
Invited user will be invited to current_department

In departments where users are leaders, they can assign other roles to other users. There must always be a leader.
In departments where users are leaders, they can send invitations.
