#!/bin/bash

# Backup the original BreaksNav component
cp /home/fred/code/fullmetal-fred/slidev-addon-rabbit/components/BreaksNav.vue /home/fred/code/fullmetal-fred/slidev-addon-rabbit/components/BreaksNav.vue.backup

# Move the refactored file into place
mv /home/fred/code/fullmetal-fred/slidev-addon-rabbit/components/BreaksNav.vue.refactored /home/fred/code/fullmetal-fred/slidev-addon-rabbit/components/BreaksNav.vue

echo "BreaksNav component has been updated with the refactored version"
echo "A backup of the original file was saved to BreaksNav.vue.backup"
