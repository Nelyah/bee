# Bee: A task management software

This is under active development as a pet project, and I discourage anyone to start using it seriously.

If you want to get started and playing with it, run the following:

```
git clone git@github.com:Nelyah/bee
cd bee
cargo run help
```


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
- [X] Dependency
    - [X] Modifying a task
    - [X] Update the blocking task
    - [X] Update the blocking task during the action and log it in undo (extra task)
    - [X] Filter on dependencies
- [X] Task Info
- [X] Task history
- [X] Improve autocompletion
- [X] Add a start and stop action
    - [X] Implement it
    - [X] Add tests
- [X] Padding on annotations that take multiple lines
- [X] Edit action
- [ ] Sync with JIRA
- [ ] Import from Taskwarrior

### Next steps

- [X] Help
- [ ] Refactor DependsOn to just be a link type in between two tasks.
- [X] due
- [X] 'export' action
- [ ] Improve Task Info with printing to a table instead of regular print
- [ ] Views (show potentially multiple reports in a single view)
- [ ] Recurring tasks
    - A task can recur:
        - time OR duration, on a set schedule
            - every <duration>
            - on list(day of month), on list(day of week), on list(day of year)
        - time OR duration after an event
            - 1 day after X is done, Monday after X is done
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
