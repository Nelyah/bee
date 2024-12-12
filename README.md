# Rusk TODO app

## TODOs:

### Required for me using it

- [X] Manage task IDs correctly
- [X] Make user error accessible to all modules
- [X] Action setters/getters macro
- [X] Done action
- [X] Delete action
- [X] Modify action
- [X] Parser for defining an action
- [X] Filters have subtypes
- [X] Customise fields in the table
- [X] Better colours in the table (alternating rows)
- [X] Parse date
- [X] Customise colours
    - [X] conditionally
- [X] Implement Undo for actions
- [X] Implement the 'undo' action
- [X] Annotations
- [X] date filters
    - [X] Date completed
    - [X] Date created
- [X] Projects and sub projects
- [X] autocompletion
    - [X] CMD action to get stuff
    - [X] Complete projects
    - [X] Complete tags
- [X] Urgency
- [ ] Dependency
    - [X] Modifying a task
    - [X] Update the blocking task
    - [X] Update the blocking task during the action and log it in undo (extra task)
    - [ ] Filter on dependencies
- [X] Task Info
- [ ] Task history
    - This is either implemented as having the entire previous state of the task
        - Probably not worth it because that info is already contained somewhere in the undos
    - Or just having a single line mentioning what happened
- [ ] Import from Taskwarrior
- [ ] Improve autocompletion

### Next steps

- [X] due
- [X] 'export' action
- [ ] Improve Task Info with printing to a table instead of regular print
- [ ] Views (show potentially multiple reports in a single view)
- [ ] Recurring tasks
- [ ] Contexts
- [ ] Descriptions
- [ ] Priority
- [ ] Warn about circular dependencies

### Nice to have

- [ ] Interactive search
- [ ] Customise data location
- [ ] Customise config location (through ENV var)
- [ ] Support for hooks
- [ ] Task duration
- [ ] Task start date
- [ ] API
- [ ] Web ui
