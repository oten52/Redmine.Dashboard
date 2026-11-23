# Redmine Dashboard

Builds a live statistical dashboard from a saved issue query.

[Türkçe](README.tr.md)

## What's new

* 0.2.0: Proportional breakdown for any column on the saved query. See [CHANGELOG](CHANGELOG.md).

## Features

* Choose one of your saved issue queries. The counts follow that query's filters and update as the issues change.
* Summary cards show the total, open, closed and unassigned counts.
* Choose the columns that belong to the query. Custom fields such as criticality and related-issue columns are included when they are on the query.
* Each selected column shows its values, the count and the share of the result.
* The same page is available from the top menu and from a project tab. Inside a project, a global query is limited to that project.

## Required Redmine version

* 4.2.x ~ 6.x

No database migration, no extra gem and no asset compilation.

## Install

1. From the Redmine `plugins` directory:

```bash
git clone https://github.com/oten52/Redmine.Dashboard.git
```

The directory name can stay `Redmine.Dashboard`.

2. Restart Redmine.

Open Pano in the top menu, or the Pano tab inside a project, then select a saved query.

## Uninstall

1. Delete the `Redmine.Dashboard` folder.
2. Restart Redmine.

## Author

Niltek Arge — https://github.com/oten52

## License

GNU General Public License v3.0 or later. See [LICENSE](LICENSE).

If you modify and distribute this plugin, keep the copyright notices, state your changes and
distribute your version under the same license.
