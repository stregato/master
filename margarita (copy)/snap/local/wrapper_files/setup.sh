#!/bin/bash

# Copy the custom MIME definition XML file to the appropriate location within the Snap
cp $SNAPCRAFT_PART_INSTALL/mg.xml $SNAP/usr/share/mime/packages/

# Update the MIME database and cache within the Snap
update-desktop-database $SNAP/usr/share/applications/
update-mime-database $SNAP/usr/share/mime