

### Looking at the raw data

To get a lits of all png and all merged png go to the dropbox folder and type

```bash
find ./ -type f | grep 'merge_' | grep '.png$' > all_png.txt
find ./ -type f | grep 'merge_' | grep '.png$' > all_merged_png.txt
```
