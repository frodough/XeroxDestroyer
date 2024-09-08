# XeroxDestroyer
Remove ghost printer entries caused by the Xerox Print Experiencce

### What does the script do?:

For some reason with v4 Xerox drivers if the Xerox Print Experience is installed there is a bug that will duplicate every installed printer for every user profile on the machine. So for example if
there are 3 printers being deployed and 50 profiles each user will have 150 printers show in Devices and Printers. They will also get a notification displaying the installation of every duplicate printer,
so if you are in an environment that has 100 people loging into a shared device you can see where this can be a major issue. These printers while they can be removed by right-click\remove printer, they will return once the user logs
off\on to the machine or the machine is restarted, in some cases these can immediately return after removal. 

This script will fix this issue by fully removing all Xerox printers from the affected device. 

This includes:
1. Fully removing all Xerox drivers
2. All registry entries
3. Fully removing Xerox Print Experience

### Why is this called Xerox Destroyer?:

Ha no this will not destroy any printer or cause any harm. After dealing with a couple hundred to a thousand computers that were all having this exact issue, I made it my mission to obliterate the constant notifications and hundreds of fake printers that clogged up users print menu, hence the title.

### How to use:

Run the script and follow the on screen instructions.
