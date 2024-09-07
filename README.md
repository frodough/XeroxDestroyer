# XeroxDestroyer
Remove ghost printer entries caused by the Xerox Print Experiencce

### What does the script do?:

For some reason with certian v3 v4 Xerox drivers if the Xerox Print Experience is installed there is a bug that will duplicate every installed printer for every user profile on the machine. So for example if
there are 3 printers being deployed and 50 profiles each user will have 150 printers show in Devices and Printer. They will also get a notification displaying the installation of every duplicate printer,
so if you are in an environment that has 100 people loging into a shared device you can see where this can be a major issue. These printers while they can be removed by right-click\remove printer, they will return once the user logs
off\on to the machine or the machine is restarted, in some cases these can immediately return after removal. 

This script will fix this issue by fully removing all Xerox printers from the affected device. 

This includes:
Fully removing all Xerox drivers
All registry entries
Fully removing Xerox Print Experience

#### How to use:

Run the script and follow the on screen instructions.
