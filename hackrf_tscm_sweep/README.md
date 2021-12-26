# A script that allows you to create signal masks and detect new signals using hackrf

## Usage:
```
./hackrf_tscm_sweep.sh --mask     # Run for a while to get the signal mask. Then close
./hackrf_tscm_sweep.sh --scan     # Scanning for new signals
./hackrf_tscm_sweep.sh --compare  # Detecting new signals
./hackrf_tscm_sweep.sh --reset    # Reset DB
```

## Example of usage:
```
# Connect HackRF
# Run for 10 minutes and stop by pressing [ENTER]
└─$ ./hackrf_tscm_sweep.sh --mask
>>> GET SIGNAL MASK
>>> Starting SWEEP SCAN
SWEEP_PID: 80994
>>> TABLE: TSCM_MASK created
>>> TABLE: SCAN created
>>> TABLE: SCAN_MASK created
>>> TABLE: TMP created
MERGE_PID: 81016
File -> scan_1640529973
SWEEP_PID: 80994
MERGE_PID: 81016
Press [ENTER] to stop scanning ...<<< scan_1640529973 IMPORTED
File -> scan_1640529983
<<< scan_1640529983 IMPORTED
# Run for scanning
└─$ ./hackrf_tscm_sweep.sh --scan
# In this example, a signal from the Ajax MotionCam was detected
└─$ ./hackrf_tscm_sweep.sh --compare
>>> COMPARE TABLES SCAN_MASK with TSCM_MASK
865000000|-70.4|-72.78|-70.78|-71.09|-71.02|-72.99|-72.38|-70.27|-71.66|-69.9|-70.25|-71.11|-71.65|-69.96|-70.83|-71.66|-72.79|-71.11|-70.95|-69.7|-71.89|-73.52|-70.93|-69.55|-66.75|-67.81|-70.4|-69.47|-69.72|-71.86|-71.47|-71.91|-71.89|-70.52|-70.88|-70.27|-72.03|-71.06|-69.53|-71.17|-71.82|-71.94|-71.31|-71.96|-70.33|-69.99|-68.18|-69.36|-70.29|-71.11|-71.24|-69.37|-70.68|-71.79|-71.6|-72.79|-71.59|-69.95|-71.4|-71.6|-70.52|-70.74|-69.31|-70.66|-72.2|-68.34|-68.31|-71.07|-71.05|-71.95|-45.82|-40.35|-46.77|-71.16|-72.48|-71.41|-71.07|-69.38|-71.75|-72.39|-73.25|-69.93|-70.59|-69.91|-71.95|-70.9|-72.24|-71.23|-72.37|-71.21|-71.25|-69.69|-69.44|-71.89|-70.2|-69.67|-69.55|-71.72|-72.03|-71|-70.94
```

## Visualize data with feedgnuplot
```
└─$ ALERT='865000000|-70.4|-72.78|-70.78|-71.09|-71.02|-72.99|-72.38|-70.27|-71.66|-69.9|-70.25|-71.11|-71.65|-69.96|-70.83|-71.66|-72.79|-71.11|-70.95|-69.7|-71.89|-73.52|-70.93|-69.55|-66.75|-67.81|-70.4|-69.47|-69.72|-71.86|-71.47|-71.91|-71.89|-70.52|-70.88|-70.27|-72.03|-71.06|-69.53|-71.17|-71.82|-71.94|-71.31|-71.96|-70.33|-69.99|-68.18|-69.36|-70.29|-71.11|-71.24|-69.37|-70.68|-71.79|-71.6|-72.79|-71.59|-69.95|-71.4|-71.6|-70.52|-70.74|-69.31|-70.66|-72.2|-68.34|-68.31|-71.07|-71.05|-71.95|-45.82|-40.35|-46.77|-71.16|-72.48|-71.41|-71.07|-69.38|-71.75|-72.39|-73.25|-69.93|-70.59|-69.91|-71.95|-70.9|-72.24|-71.23|-72.37|-71.21|-71.25|-69.69|-69.44|-71.89|-70.2|-69.67|-69.55|-71.72|-72.03|-71|-70.94'
└─$ FREQ=$(echo "$ALERT" | cut -d '|' -f 1); x=2; for ((i=0;i<=100;i++)); do echo $(echo "scale=2; $(($FREQ+$i*50000))/1000000" | bc -l )" "$(echo "$ALERT" | cut -d "|" -f $x); x=$(($x+1)); done | feedgnuplot --domain --lines
```
![image](https://user-images.githubusercontent.com/56395503/147414541-796f5ae6-5cff-45be-ab1c-148ac5cf9fb6.png)

