;SAM4SN - Spread of Awareness Model for Social Norms
extensions [web table]

breed [blinds blind]
breed [indifferents indifferent]
breed [spectators spectator]
breed [actives active]
breed [evangelists evangelist]

globals [total-agent-number
         current-N-blinds
         current-N-indifferents
         current-N-spectators
         current-N-actives
         current-N-evangelists
         green-fraction
         global-resource-consumption
         global-resource-production
         global-resource-use
         delta-resource
         elementar-unit
         elementar-unit-number
         total-elementar-unit
         sustainability-tipping-point
         unsustainability-tipping-point
    ;;;GLOBAL VARIABLES THAT ARE SUPPLIED BY THE USER INTERFACE
      ;N-blind, N-indifferent,...:initial number of types of agents
      Influence-radius
      ;seed
      ;Initial-global-resource-consumption
      ;Reduction-goal at general level (in Percentage)
      ;metering-availability  ON/OFF
       ;individual-feedback  ON/OFF
        ;neighbour-comparison ON/OFF
         ;Tips&Tricks ON/OFF
         ]
turtles-own
         [awareness
         initial-individual-resource-consumption
          metering
          feedback
          comparison
          suggestion
          own-resource-consumption
          own-resource-production
          resource-reduction-goal
          old-own-resource-consumption
          delta-individual-consumption
          reinforcement
          initial_time_p
      ;;;REPORTER
         ;minimal-consumption: is a reporter and acts as reference resource consumption
         ;green-competition-index: is a report
          ]

;;;______________SETUP PROCEDURES________________
to SETUP
   ca
   random-seed seed
   ;;;AGENTS CREATION AND AWARENESS INITIALISATION
   set total-agent-number (N-blinds + N-indifferents + N-spectators + N-actives + N-evangelists)
   SET-BREED-SHAPE; give a shape to each agent type
   CREATE-AGENTS;create agents on free patches
   INITIAL-AWARENESS ;set initial awareness value
   GIVE-COLOR

   ;;;CONSUMPTIONS INITIALISATION
   set elementar-unit-number  (N-blinds * 1.4 + N-indifferents * 1.3 + N-spectators * 1.2 + N-actives * 1.1  + N-evangelists * 1)
   set elementar-unit Initial-global-resource-consumption / elementar-unit-number

   ask blinds [set initial-individual-resource-consumption elementar-unit * 1.4]
   ask indifferents [set initial-individual-resource-consumption elementar-unit * 1.3]
   ask spectators [set initial-individual-resource-consumption elementar-unit * 1.2]
   ask actives [set initial-individual-resource-consumption elementar-unit * 1.1]
   ask evangelists [set initial-individual-resource-consumption elementar-unit ]


   set Influence-radius 2
   set global-resource-consumption Initial-global-resource-consumption
   set global-resource-use global-resource-consumption
   set global-resource-production 0
   set delta-resource 0

   SETUP-SOCIAL-REINFORCEMENT
   SETUP-BREED-VARIABLES
   reset-ticks
end

to SETUP-SOCIAL-REINFORCEMENT
  ask turtles [set reinforcement 0]
  set sustainability-tipping-point false
  set unsustainability-tipping-point false
end

to SETUP-BREED-VARIABLES
   ask turtles  [set own-resource-consumption initial-individual-resource-consumption
                 set resource-reduction-goal 0
                 set own-resource-production 0
                 set initial_time_p random 100
                       ifelse metering-availability
                              [set metering true]
                              [set metering false
                              ]
                       ifelse individual-feedback
                              [set feedback true]
                              [set feedback false]
                       ifelse neighbour-comparison
                              [set comparison true]
                              [set comparison false]
                       ifelse Tips&Tricks
                              [set suggestion true]
                              [set suggestion false]
                       set own-resource-production 0
                       ]
   ask evangelists  [set own-resource-production initial-individual-resource-consumption * 0.1]
end

to-report QUERY_SMART_METER [time_p forecast]
  ifelse forecast
        [ report min read-from-string item 0 web:make-request  (word "http://127.0.0.1:9171/smart-meter/" time_p "?forecast-enabled=true") "GET" [] [] ]
        [ report min read-from-string item 0 web:make-request  (word "http://127.0.0.1:9171/smart-meter/" time_p) "GET" [] [] ]
end

;;;_____________GO PROCEDURE_________________________
to GO
   set green-fraction current-N-green / total-agent-number
   tick
   UPDATE-AWARENESS
   UPDATE-BREEDS
   COUNT-CURRENT-BREED
   GIVE-COLOR
   ;;;CONSUMPTIONS
   UPDATE-REDUCTION-GOAL
   UPDATE-CONSUMPTION
   ;;;SOCIAL NORMS
   SOCIAL-REINFORCEMENT
   if global-resource-use <= (Initial-global-resource-consumption - (Initial-global-resource-consumption * Reduction-goal) / 100)
       [output-print "Overall Reduction Goal has been reached"
        output-type "Social norm about sustainability is " output-type sustainability-tipping-point
     stop]
end

to-report current-N-green
  report current-N-actives + current-N-evangelists
end

;;;_______BREED REDUCTION GOALS____________________
to UPDATE-REDUCTION-GOAL
    ask blinds   [set resource-reduction-goal (initial-individual-resource-consumption * -0.01)]
    ;resource reduction goal is negative: blind will increase his consumption of 0.01 his initial-individual-resource-consumption

;;; METERING AND NOT COMPARISON   rgi= orci* Ki
    ask indifferents with [metering and not comparison]
         [set resource-reduction-goal 0]  ;no reduction goal
    ask spectators  with [metering and not comparison]
         [set resource-reduction-goal (own-resource-consumption * 0.001)]
         ;resource reduction goal is the 0.1% of own-resource-consumption
    ask actives with [metering and not comparison]
         [set resource-reduction-goal (own-resource-consumption * 0.05)]
         ;resource reduction goal is the 5% of own-resource-consumption
    ask evangelists with [metering and not comparison]
         [set resource-reduction-goal (own-resource-consumption * 0.15)]
        ;resource-reduction-goal is the 15% of own-resource-consumption

;;; METERING AND COMPARISON rgi= (orci - minimal-consumption) * green-competition-index
  ask indifferents with [metering and comparison]
      [set resource-reduction-goal ((own-resource-consumption - minimal-consumption) * green-competition-index)]
  ask spectators with [metering and comparison]
      [set resource-reduction-goal ((own-resource-consumption - minimal-consumption) * green-competition-index)]
  ask actives with [metering and  comparison]
      [set resource-reduction-goal ((own-resource-consumption - minimal-consumption) * green-competition-index)]
  ask evangelists with [metering and  comparison]
      [set resource-reduction-goal ((own-resource-consumption - (minimal-consumption * 0.95)) * green-competition-index)]
end

 ;;; MINIMAL CONSUMPTION is a report
 to-report minimal-consumption
   ifelse (min [own-resource-consumption] of turtles != initial-individual-resource-consumption)
          [report min [own-resource-consumption] of turtles]
          [report initial-individual-resource-consumption * 0.95]
  end

 ;;; GREEN COMPETITION INDEX is a report and is value is 1 - (1 / (awareness -8)) when  awareness is larger than 8, is 0 for blind agents
 to-report green-competition-index
  ifelse (awareness > 8 ) [report   1 -  (1 / (awareness - 8))]
         [report 0]
 end

 to UPDATE-CONSUMPTION
   let old-resource-use global-resource-use
   UPDATE-INDIVIDUAL-RESOURCE-CONSUMPTION
   set global-resource-consumption (sum [own-resource-consumption] of turtles)
   set global-resource-production (sum [own-resource-production] of evangelists)
   set global-resource-use  (global-resource-consumption - global-resource-production)
   set delta-resource ((global-resource-use - old-resource-use) / global-resource-use)
   ;delta-resource must be negative to have a reduction trend
 end

 ;_______________ INDIVIDUAL CONSUMPTION _________________________________
 to UPDATE-INDIVIDUAL-RESOURCE-CONSUMPTION
   ask turtles [set old-own-resource-consumption own-resource-consumption]

              ;;; ALL BLINDS -  blinds increase each run their own consumption
   ask blinds [set own-resource-consumption  (own-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) false - (resource-reduction-goal * 0.1))]
             ;;; ALL INDIFFERENTS - indifferent own consumption is always the same
   ask indifferents [set own-resource-consumption (initial-individual-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) false)]

              ;;;METERING  NO FEEDBACK NO SUGGESTION orci= orci - rg * 0.01
   ask turtles with [metering and not feedback and not suggestion]
           [set own-resource-consumption (own-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) false - (resource-reduction-goal * 0.01))]

              ;;;METERING  AND SUGGESTION  NO FEEDBACK  orci= orci - rg * 0.02 INDIPENDENTE DA COMPARISON
   ask turtles with [metering and not feedback and suggestion]
           [set own-resource-consumption (own-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) false - (resource-reduction-goal * 0.02))]

              ;;;METERING AND FEEDBACK  NO SUGGESTION  orci= orci - rg * Wi
   ask spectators with [metering and feedback and not suggestion]
           [set own-resource-consumption (own-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) true - (resource-reduction-goal * 0.0125))]
   ask actives with [metering and feedback and not suggestion]
           [set own-resource-consumption (own-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) true - (resource-reduction-goal * 0.025))]
   ask evangelists with [metering and feedback and not suggestion]
           [set own-resource-consumption (own-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) true - (resource-reduction-goal * 0.05))]

              ;;; METERING AND FEEDBACK AND SUGGESTION orci= orci - rg * Wi*2
   ask spectators with [metering and feedback and suggestion]
           [set own-resource-consumption (own-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) true - (resource-reduction-goal * 0.025))]
   ask actives with [metering and feedback and  suggestion]
           [set own-resource-consumption (own-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) true - (resource-reduction-goal * 0.05))]
   ask evangelists with [metering and feedback and  suggestion]
           [set own-resource-consumption (own-resource-consumption + QUERY_SMART_METER (ticks + initial_time_p) true - (resource-reduction-goal * 0.1))]

              ;;;DELTA INDIVIDUAL CONSUMPTION
   ask turtles
       [set delta-individual-consumption ((own-resource-consumption - old-own-resource-consumption - own-resource-production) / own-resource-consumption)]

             ;;;RESOURCE PRODUCTION
   ask evangelists  [set own-resource-production own-resource-consumption * 0.02]
   end
              ;;;SOCIAL REINFORCEMENT
 to SOCIAL-REINFORCEMENT
  ask blinds [
    ifelse ((delta-resource > 0) and delta-individual-consumption > 0)
            [set reinforcement  -1]
            [set reinforcement  0]]

  ask indifferents [
   if ((delta-resource < 0) and delta-individual-consumption < 0 and (abs delta-resource > abs delta-individual-consumption))
             [set reinforcement  1]
   if ((delta-resource > 0) and delta-individual-consumption > 0 and (abs delta-resource > abs delta-individual-consumption))
             [set reinforcement  -1]]

  ask spectators [
    if ((delta-resource < 0) and delta-individual-consumption < 0 and (abs delta-resource > abs delta-individual-consumption))
              [set reinforcement  1]
    if ((delta-resource > 0) and delta-individual-consumption > 0 and (abs delta-resource > abs delta-individual-consumption))
              [set reinforcement  -1]]

  ask actives [
    if ((delta-resource < 0) and delta-individual-consumption < 0)
               [set reinforcement  1]]

  ask evangelists [
    if ((delta-resource < 0) and delta-individual-consumption < 0) ;and (abs delta-resource > abs delta-individual-consumption))
              [set reinforcement  1]]

        ;;;SOCIAL NORM
  ifelse(ticks > 4 and (count actives with [delta-individual-consumption <= 0] + count evangelists with [delta-individual-consumption <= 0]) / total-agent-number > 0.1)
                   and delta-resource < 0
                   and (count turtles with [reinforcement = 1]) > (count turtles with [reinforcement = -1])
              [set sustainability-tipping-point true]
              [set sustainability-tipping-point false]

ifelse (ticks > 4 and (count blinds with [delta-individual-consumption > 0]) / total-agent-number > 0.1)
                  and delta-resource > 0
                  and (count turtles with [reinforcement = -1]) > (count turtles with [reinforcement = 1])
              [set unsustainability-tipping-point true]
              [set unsustainability-tipping-point false]
 end

;;;__________CREATION OF AGENTS AND AWARENESS SETUP_______________
to SET-BREED-SHAPE
   set-default-shape blinds "x"
   set-default-shape indifferents "triangle"
   set-default-shape spectators "square"
   set-default-shape actives "pentagon"
   set-default-shape evangelists "circle"
end

to CREATE-AGENTS
   create-blinds N-blinds
   create-indifferents N-indifferents
   create-spectators N-spectators
   create-actives N-actives
   create-evangelists N-evangelists
   find-a-free-patch-for-every-agents
   ask turtles [set color grey]
end

to find-a-free-patch-for-every-agents
   ask blinds
    [set xcor random-pxcor
        set ycor random-pxcor
    if (any? other turtles-here) [find-new-spot]]
   ask indifferents
    [set xcor  random-pxcor
    set ycor  random-pycor
    if (any? other turtles-here) [find-new-spot]]
   ask spectators
    [set xcor  random-pxcor
    set ycor  random-pxcor
    if (any? other turtles-here) [find-new-spot]]
   ask actives
    [set xcor  random-pxcor
    set ycor  random-pxcor
    if (any? other turtles-here) [find-new-spot]]
   ask evangelists
    [set xcor random-pxcor
    set ycor  random-pxcor
    if (any? other turtles-here) [find-new-spot]]
 end
 to find-new-spot  ;this procedure comes from the segregation model
    rt random-float 360
    fd random-float 10
    if any? other turtles-here
      [ find-new-spot ] ;; keep going until we find an unoccupied patch
    move-to patch-here  ;; move to center of patch
end

 to INITIAL-AWARENESS
   ask blinds [set awareness 0]
   ask indifferents [set awareness 8]
   ask spectators  [set awareness 16]
   ask actives  [set awareness 100]
   ask evangelists [set awareness 2000]
end

to GIVE-COLOR; give colors to breeds
   ask blinds [set color red]
   ask indifferents [set color brown]
   ask spectators  [set color yellow]
   ask actives  [set color green]
   ask evangelists [set color blue]
end

;;;_____________AWARENESS UPDATE_______________
to UPDATE-AWARENESS
   ask blinds
       [if (any? evangelists in-radius (Influence-radius * 2)  or (any? actives in-radius Influence-radius))
                [set awareness awareness + 1]
       if (any? blinds in-radius Influence-radius)
                [set awareness awareness - 2]]

   ask indifferents
       [if (any? evangelists in-radius (Influence-radius * 2)) or (any? actives in-radius Influence-radius)
                [set awareness awareness + 1]
       if (any? blinds in-radius Influence-radius)
                [set awareness awareness - 1]]

   ask spectators
        [if (any? evangelists in-radius (Influence-radius * 2) or (any? actives in-radius Influence-radius))
                 [set awareness awareness + 1]
        if (any? blinds in-radius Influence-radius)
                 [set awareness awareness - 1]
        if (green-fraction > 0.3)
                 [set awareness awareness + 1]]

   ask actives
         [if (any? evangelists in-radius (Influence-radius * 2))
                 [set awareness awareness + 2]
         if (green-fraction > 0.8)
                 [set awareness awareness + 1]]

   ask blinds [set awareness  (awareness + reinforcement)]
   ask indifferents [set awareness  (awareness + reinforcement)]
   ask spectators [set awareness  (awareness + reinforcement)]
   ask actives [set awareness  (awareness + reinforcement)]
end

to UPDATE-BREEDS
   ask turtles with [ awareness < 8] [set breed blinds]
   ask turtles with [(awareness >= 8) and (awareness < 16)] [set breed indifferents]
   ask turtles with [(awareness >= 16) and (awareness < 100)] [set breed spectators]
   ask turtles with [awareness >= 100 and (awareness < 2000)] [set breed actives]
   ask turtles with [awareness >= 2000] [set breed evangelists]
end

to COUNT-CURRENT-BREED
   set current-N-blinds count blinds
   set current-N-indifferents count indifferents
   set current-N-spectators count spectators
   set current-N-actives count actives
   set current-N-evangelists count evangelists
end

to exportGRPlotAndInterface
export-plot "GLOBAL RESOURCE" word date-and-time "GlobalResourceConsumptionmyPlot.csv"
export-interface word date-and-time "myInterface.png"
end


;;; The SAM4SN SAM4SNmodel is implemented by Giovanna Sissa, Università degli Studi di Genova Copyright (C) 2015 G. Sissa
@#$#@#$#@
GRAPHICS-WINDOW
424
15
836
428
-1
-1
12.242424242424242
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
25
10
88
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
24
99
87
132
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

OUTPUT
865
10
1180
85
11

SLIDER
163
10
335
43
N-blinds
N-blinds
0
50
20.0
1
1
NIL
HORIZONTAL

SLIDER
163
50
335
83
N-indifferents
N-indifferents
0
300
298.0
1
1
NIL
HORIZONTAL

SLIDER
162
87
334
120
N-spectators
N-spectators
0
300
148.0
1
1
NIL
HORIZONTAL

SLIDER
163
124
335
157
N-actives
N-actives
0
200
62.0
1
1
NIL
HORIZONTAL

SLIDER
162
164
334
197
N-evangelists
N-evangelists
0
50
2.0
1
1
NIL
HORIZONTAL

BUTTON
22
53
85
86
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
435
460
831
600
Number of different type of Agents
tick
N. of agents
0.0
50.0
0.0
100.0
true
true
"clear-all-plots" ""
PENS
"blind" 1.0 0 -2674135 true "" "plot count blinds"
"indifferent" 1.0 0 -6459832 true "" "plot count indifferents"
"spectators" 1.0 0 -1184463 true "" "plot count spectators"
"active" 1.0 0 -10899396 true "" "plot count actives"
"evangelist" 1.0 0 -13345367 true "" "plot count evangelists"

SWITCH
4
134
162
167
metering-availability
metering-availability
0
1
-1000

PLOT
865
120
1134
300
Individual consumption levels
OwnResCons
turtles
30.0
60.0
0.0
200.0
true
true
"clear-all-plots\nset-plot-x-range 0 (initial-global-resource-consumption / total-agent-number)\nset-plot-y-range 0 total-agent-number\nset-histogram-num-bars 3" ""
PENS
"OwnResCons" 1.0 1 -5298144 true "" "histogram [own-resource-consumption] of turtles"

SLIDER
136
237
384
270
Initial-global-resource-consumption
Initial-global-resource-consumption
100
50000
26000.0
100
1
NIL
HORIZONTAL

PLOT
31
271
410
602
GLOBAL RESOURCE
ticks
RESOURCE  USE
0.0
50.0
0.0
10000.0
true
true
"clear-all-plots" "set-plot-y-range (Initial-global-resource-consumption * 0.8) (Initial-global-resource-consumption * 1.2)"
PENS
"CONSUMPTION" 1.0 0 -2674135 true "" "plot global-resource-consumption"
"USE" 1.0 0 -7500403 true "" "plot global-resource-use"

PLOT
855
312
1170
602
Awareness
awareness level
Number of agents
0.0
2500.0
0.0
100.0
false
true
"set-plot-pen-mode 1\nset-plot-y-range 0 total-agent-number\nset-plot-x-range 0 2500\nset-histogram-num-bars 20" "histogram [awareness] of turtles"
PENS
"default" 1.0 1 -13210332 true "" "histogram [awareness] of turtles"

INPUTBOX
334
10
423
70
Reduction-goal
10.0
1
0
Number

SWITCH
4
167
164
200
individual-feedback
individual-feedback
0
1
-1000

SWITCH
4
202
178
235
neighbour-comparison
neighbour-comparison
0
1
-1000

SWITCH
5
237
136
270
Tips&Tricks
Tips&Tricks
0
1
-1000

INPUTBOX
1190
75
1269
145
seed
10000.0
1
0
Number

MONITOR
1170
255
1365
300
SUSTAINABILITY tipping point
sustainability-tipping-point
0
1
11

MONITOR
1170
155
1380
200
UNSUSTAINABILITY tipping point
unsustainability-tipping-point
0
1
11

@#$#@#$#@
## WHAT IS IT?

The  SAM4SN model  reproduces how environmental awareness spreads between agents and how such awareness impacts on the critical resource consumption.
Each agents represents a household.

## HOW IT WORKS

There are five types of agents: blinds, indifferents, osservatori, actives and evangelists.

Shapes and colors are different for every types.

## HOW TO USE IT

The user, by the sliders, initialises the number of different types.
The user assigns by the interface also:
- the (numerical) value of the critical resource that have to be reduced. Such resource can be water or energy. 
- the overall reduction goal (in percentage)
- the availability of four smart metering functions (ON/OFF)

Pushing the bottom "setup" the system is configured with the given inputs.
Pushing the bottom "go" the system runs for one tick.
Pushing the bottom "go" with two arrow the system runs forever and stops only if and when the required reduction is reached.

Other input variables that the user can modify are "influence-radius"  and "seed":
- Influence-radius impacts only on awareness of blinds agents;
- seed is the random seed influencing the position of agents.

Such variable can be modified only in this preliminary version. 

The results are supplied by four plots and two histograms.
The plots visualize:
- The global resource consumption over the time (one tick= one week); 
- The global resource production (i.e. recycled water, if the critical resource to be reduced is water,  or the energy produced by the household)
- The number of different types of agents
- The minimum value of consumption among the agents: when the smart metering function enabling the comparison between household consumptions is available (i.e. neighbour-comparison is ON") such value is available to everybody and  defines the individual reduction goal.

Histograms visualize:
- the number of turtles with a given individual consumption
- the number of turtles with a given awareness


## COPYRIGHT AND LICENCE
The SAM4SN SAM4SNmodel is implemented by Giovanna Sissa, Università degli Studi di Genova

Copyright (C) 2015 G. Sissa

SAM4SN is a Netlogo implementation of the theoretical model developped by  Giovanna Sissa in  her PhD thesis "FROM MICRO BEHAVIORS TO MACRO EFFECTS - AGENT BASED MODELING OF ENVIRONMENTAL AWARENESS SPREAD AND ITS EFFECTS ON THE CONSUMPTION OF A LIMITED RESOURCE",  Università degli studi di Milano. DIPARTIMENTO DI INFORMATICA, 2014

Please see the ODD protocol for this model on Openabm.org for more detailed information. 
This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/

## CREDITS AND REFERENCES
Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="tipping point" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>sustainability-tipping-point = true</exitCondition>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influence-radius">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="tipping point -3" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="350"/>
    <metric>sustainability-tipping-point</metric>
    <metric>unsustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N-evangelists" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influence-radius">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="tipping point -3" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="540"/>
    <metric>sustainability-tipping-point</metric>
    <metric>unsustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N-evangelists" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influence-radius">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random-seed" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
      <value value="3355"/>
      <value value="76842"/>
      <value value="111"/>
      <value value="27"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="206"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influence-radius">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random-seed-2-4-ev" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
      <value value="3355"/>
      <value value="76842"/>
      <value value="111"/>
      <value value="27"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N-evangelists" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="N-spectators">
      <value value="206"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influence-radius">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="tipping-response.time-with-grc" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-consumption</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="206"/>
      <value value="184"/>
      <value value="98"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="27"/>
      <value value="348"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Tipping-monotonicity" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="90"/>
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="98"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="348"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random-seed-5-ev-1-10" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
      <value value="3355"/>
      <value value="76842"/>
      <value value="111"/>
      <value value="27"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N-evangelists" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="N-spectators">
      <value value="206"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influence-radius">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="tipping point" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>sustainability-tipping-point = true</exitCondition>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influence-radius">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random-seed-5-ev-1-10-5-seeds" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
      <value value="3355"/>
      <value value="76842"/>
      <value value="111"/>
      <value value="27"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N-evangelists" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="N-spectators">
      <value value="206"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influence-radius">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="20-4-density" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="37"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="30-4-density-long" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="40-4-density-long" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="50-4-density-long" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TP-50-35-12060-30" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TP-50-35-12060-30" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="20-4-density-ru" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="37"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BE-Very-crowded-20-30-40-50" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="30-4-density-long-ru" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="40-4density-feedbacktrue" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="300"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-consumption</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BAE-40-3-seed" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-consumption</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="345"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="delay-no-sust" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="300"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-consumption</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BAE-40" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-consumption</metric>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="table-22" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-consumption</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="90"/>
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="98"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="348"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="table-22-tris" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <metric>(Initial-global-resource-consumption * Reduction-goal) / 100</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="90"/>
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="98"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="348"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Table-20" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-consumption</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="206"/>
      <value value="184"/>
      <value value="98"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="27"/>
      <value value="348"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-25-BAE20" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-26-BAE30" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-27-BAE40" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-28-BAE50" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="UTP-TABLE-28-BAE50" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>unsustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Figure-40" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Figure-38" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Figure-45" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-NEW" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-FB" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-NOMT" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-NEW-1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="987654321"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-LARGE" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="987654321"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-25-BAE20-1200" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1200"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-26-BAE30-1200" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1200"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-25-BAE20-caso1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1600"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-27-BAE40-1200" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1200"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-28-BAE50-1200" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1200"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-NEW-BIS" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="10"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="10"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="table-6" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="350"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="table-7" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="table-8" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-spectators">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="298"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-BASIC" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="2"/>
      <value value="3"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
      <value value="70"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-BASIC-FB" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="2"/>
      <value value="3"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
      <value value="70"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TABLE-BASIC-CP" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="800"/>
    <metric>sustainability-tipping-point</metric>
    <metric>global-resource-use</metric>
    <enumeratedValueSet variable="N-blinds">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-evangelists">
      <value value="2"/>
      <value value="3"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-actives">
      <value value="62"/>
      <value value="70"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tips&amp;Tricks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-spectators">
      <value value="240"/>
      <value value="120"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N-indifferents">
      <value value="300"/>
      <value value="150"/>
      <value value="74"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reduction-goal">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metering-availability">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighbour-comparison">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-global-resource-consumption">
      <value value="26000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="individual-feedback">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
