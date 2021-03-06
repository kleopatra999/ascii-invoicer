# ascii invoicer

## Introduction

The ascii-invoicer is a command-line tool that manages projects and stores them not in a database but in a folder structure. New projects can be created from templates and are stored in a working directory. Projects can be archived, each year will have its own archive. A project consists of a folder containing a yaml file describing it and a number of attached files, such tex files. Projects can contain products and personal. You can create preliminary offers and invoices from your projects.

## Installation

Should be as easy as `$ gem install ascii_invoicer`.
You might need **rvm** to install it in your `$HOME` directory, otherwise use `$ sudo gem install ascii_invoicer`.
New versions should be automatically updated via `$ gem update`.

## Usage

Each of these sections starts with a list of commands.
Read the help to each command with `ascii help [COMMAND]` to find out about all parameters, especially *list* has quite a few of them.

### Get started with

```bash
ascii help [COMMAND]                # Describe available commands or one specific command
ascii list                          # List current Projects
ascii display NAMES                 # Shows information about a project in different ways
```

### Project Life-Cycle

```bash
ascii new NAME                      # Creating a new project
ascii edit NAMES                    # Edit project
ascii offer NAMES                   # Create an offer from project
ascii invoice NAMES                 # Create an invoice from project
ascii archive NAME                  # Move project to archive
ascii reopen YEAR NAME              # reopen an archived project
```

### GIT Features

```bash
ascii add NAMES
ascii commit -m, --message=MESSAGE
ascii log
ascii pull
ascii push
ascii status
```

These commands behave similar to the original git commands.
The only difference is that you select projects just like you do with other ascii commands (see edit, display, offer, invoice).
Commit uses -m (like in git) but unlike git does not (yet) open an editor if you leave out the message.

#### CAREFUL:
These commands are meant as a convenience, they ARE NOT however a *complete* replacement for git!
You should always pull before you start working and push right after you are done in order to avoid merge conflicts.
If you do run into such problems go to storage directory `cd $(ascii path)` and resolve them using git.

Personal advice N°1: use `git pull --rebase`

Personal advice N°2: add this to your .bash_aliases:
`alias agit="git --git-dir=$(ascii path)/.git --work-tree=$(ascii path)"`

### More Details

The commands `ascii list` and `ascii display` (equals `ascii show`) allow to display all sorts of details from a project.
You can define sort of path through the document structure to the key you want to be displayed.
`ascii show -d client/email` will display the clients email.
`ascii show -d invoice/date` will display the date of the invoice.

`ascii list --details` will add columns to the table.
For example try `ascii list --details client/fullname client/email`


### Exporting

```bash
ascii calendar # Create a calendar file from all caterings named "invoicer.ics"
ascii csv      # Prints a CSV list of current year into CSV
```
You can pipe the csv into column (`ascii csv | column -ts\;`) to display the table in you terminal.

### Miscellaneous 

```bash
ascii path      # Return projects storage path
ascii settings  # View settings
ascii templates # List or add templates
ascii whoami    # Invoke settings --show manager_name
ascii version   # Display version
```

## Filesstructure

Your config-file is located in ~/.ascii-invoicer.yml but you can also access it using `ascii settings --edit` or even `ascii edit --settings`.
The projects directory contains working, archive and templates. If you start with a blank slate you might want to put the templates folder into the storage folder (not well tested yet).

By default in your `path` folder you fill find:

```
caterings
├── archive
│   ├── 2013
│   │   ├── Foobar1
│   │   │   └── Foobar1.yml
│   │   └── Foobar2
│   │       ├── Foobar2.yml
│   │       └── R007 Foobar2 2013-02-11.tex
│   └── 2014
│       ├── canceled_foobar1
│       │   ├── A20141009-1 foobar.tex
│       │   └── foobar1.yml
│       ├── R029_foobar2
│       │   └── R029 foobar2 2014-09-10.tex
│       └── R036_foobar3
│           ├── foobar3.yml
│           └── R036 foobar3 2014-10-08.tex
├── templates
│   ├── default.yml.erb
│   └── document.tex.erb
└── working
    ├── Foobar1
    │   ├── A20141127-1 Foobar1.tex
    │   └── Foobar1.yml
    ├── Foobar2
    │   ├── A20141124-1 Foobar2.tex
    │   └── Foobar2.yml
    └── Foobar3
        ├── A20140325-1 Foobar3.tex
        ├── A20140327-1 Foobar3.tex
        ├── R008 Foobar3 2014-03-31.tex
        └── Foobar3.yml
```

## Aliases

* `list`: `-l`, `l`, `ls`, `dir`
* `display`: `-d`, `show`
* `archive`: `close`
* `invoice`: `-l`
* `offer`: `-o`
* `settings`: `config`
* `log`: `history`

## Pro tips

1. Check out `repl ascii`!
You should copy [repl-file](src/repl/ascii) into ~/.repl/ascii and install rlwrap to take advantage of all the repl goodness such as autocompletion and history.

2. Check out `xclip`!
You can pipe the output of `ascii show` or `ascii show --csv` to xclip and paste to your email program or into a spreadsheet tool like libreoffice calc.


## Known Issues

Some strings may cause problems when rendering latex, e.g.
a client called `"ABC GmbH & Co. KG"`.
The `"&"` causes latex to fail, `\&"` bugs the yaml parser but `"\\&"` will do the trick.


# Building

```bash
# lets install building dependencies
cd src
gem install bundler # if you don't already have it
bundle install # pulls all building dependencies
# actually now you're done

# after you made your own changes
rake install # installs the gem
rake gem # builds the gem

# that's it
```

## Dependencies

* rvm works best, otherwise I have not tested installing it anywhere else
* a lot of latex packages to run the offer/invoice export
