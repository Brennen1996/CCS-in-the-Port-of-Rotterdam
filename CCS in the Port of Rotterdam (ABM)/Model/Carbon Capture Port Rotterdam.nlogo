extensions [csv]

breed [governments government]
breed [ports port]
breed [industries industry]
breed [storages storage]

;The globals are the parameters set by the course manager
;but to be able to change them easily to test out different compositions,
;they are used as globals
;Also some of the kpi's are used as globals
globals
[ number-of-storages
  min-oil-demand
  co2-emissions-per-ton-oil
  electricity-price
  co2-price
  capture-capex
  capture-opex-electricity
  storage-opex
  connection-to-storage-price
  max-capture
  co2-price-list
  year
  co2-emitted-per-year
  co2-stored-per-year
  total-stored-co2
  total-emitted-co2
  total-co2
  total-subsidy-port
  total-subsidy-industries
  total-electricity-use
]

;Altough links already have an end1 and an end2, the attributes of connected- storage and industry make it easy to see who is connected to who.
;The co2-stream attribute is the amount of co2 streaming through the link
links-own
[ connected-storage
  connected-industry
  co2-stream
  storage-link-price
]

;The attributes of storages are all the given columns in the csv file, to give a clear view on the characteristics of all of the storages
;Also we interpreted the storage and the pipeline that goes to the storage as one and the same
;That is why the storage has a capacity
storages-own
[ onshore-distance
  offshore-distance
  available?
  extensible?
  space-left
  capacity
  name
  capex-onshore
  capex-offshore
  storage-capex
  time-to-build
  storage-price
]

governments-own
[ government-subsidy
  available-budget-industries
  available-budget-port
]

ports-own
[ extensible-willing?
  budget
  payback-time
]

industries-own
[ capture-technology?
  payback-period
  captured-co2
  emitted-co2
  oil-usage
  created-co2
  capture-capacity
  sendable-co2
  stored-co2
]


to setup
  clear-all
  file-close-all ; Close any files from last runs
  reset-ticks
  ;random-seed -2011672772
  setup-globals
  read-co2-price
  setup-industries
  setup-government
  setup-port
  setup-storages
  read-storagelocations
end

;Here the parameters of the model are set, this is where they should be changed for experimentation
to setup-globals
  set number-of-storages 12
  set year 0
  set min-oil-demand 1 ;Mt/yr
  set co2-emissions-per-ton-oil 3.2 / 4 ;t CO2 / t oil (divided by 4 because ticks are quarters and the data given is in years)
  set electricity-price electricity-price-slider ;EUR / MWh
  set capture-capex 200 ;M EUR / Mt CO2
  set capture-opex-electricity 130 ; MWh / t CO2
  set storage-opex 0.3 ; M EUR / Mt CO2
  set total-stored-co2 0
  set total-emitted-co2 0
  set total-co2 0
  set max-capture 5
  set total-subsidy-port 0
  set total-subsidy-industries 0
  set connection-to-storage-price 1 ;M EUR/Company
end

to read-co2-price
  file-close-all
    ;Error-catch if file cannot be found
  if not file-exists? "co2price.csv" [
    user-message "The co2price.csv file does not exist! Try adding it to your folder first."
    stop
  ]
  ;Read in the file
  let file csv:from-file "co2price.csv"
  set co2-price-list []
  let i 2
  loop[
    if i = length file[stop]
    ;Put only the price at the end of a list, so a list is created of only the price over time
    set co2-price-list insert-item length co2-price-list co2-price-list (item 1 (item i file))
    set i i + 1
  ]
end

to setup-industries
  ;To create the industries in the place where we want them to be, every iteration of the loop only one industry is built.
  let i 0
  loop[
    if i = number-of-industries[stop]
    create-industries 1
    [ set shape "container"
      set size 2
      set color grey
      set emitted-co2 0
      set captured-co2 0
      set stored-co2 0
      set capture-technology? False
      set payback-period (random 20) + 1
      setxy ((i mod 10) * 3.2 + 1.6) (round((who + 5) / 10) * 4) - 3
      ;the x coordinate is calculated so that the industries are equally distributed over the grid
      ;the y coordinate is calculated in a way that only 10 industries exist on 1 row

      ;The oil-usage is a random number between a minimum and a maximum
      set oil-usage (random (max-oil-demand - min-oil-demand)) + min-oil-demand
      set created-co2 3.2 * oil-usage
    ]
  set i i + 1
  ]
end

to setup-government
  create-governments 1
  [ setxy 2 30
    set shape "building institution"
    set color green
    set size 3
    set government-subsidy subsidiy-total / 4  ;divided by 4 because the subsidy is shared every quarter instead of every year like the data suggests
    set available-budget-port government-subsidy * percentage-port / 100
    set available-budget-industries government-subsidy - available-budget-port
  ]
end

to setup-port
  create-ports 1
  [ setxy  30 30
    set shape "building institution"
    set size 3
    set color red
    set budget 0
    set payback-time 15
  ]
end

to setup-storages
  ;Notice that all the available storages are 'built' in the beginning of the model, even though they do not exist for real yet.
  let i 0
  loop[
    ;The storages are being placed at their right position
    ;Because the given number of storages is 12, but we want our model to be easily adjustable,
    ;a second row is reserved for possible new storages, if only the 12 standard storages are taken into account, they will be on one row
    if i = number-of-storages[stop]
    create-storages 1[
      if i > 11[
        setxy (i - 10)* 2.7  20
      ]
      if i < 12[
        setxy (i * 2.7 + 1) 25
      ]
      set shape "i beam"
      set size 2
      set color grey
      set available? False
      set extensible? False
    ]
  set i i + 1
  ]
end

to read-storagelocations
  file-close-all

  ;Error-catch if file cannot be found
  if not file-exists? "StorageLocations.csv" [
    user-message "The StorageLocations.csv file does not exist! Try adding it to your folder first."
    stop
  ]

  ;Read in the file
  let file csv:from-file "StorageLocations.csv"

  ;; Set an agentset - order it by lowest value ID storage so it goes from left to right
  ;; then assign the variables from the csv file to the storage facility.
  let i 0
  loop[
    if i = length file - 1[stop]

    let current item (i + 1) file
    ask item i sort storages with [color = grey] [
      set capacity item 3 current * capacity-multiplicative ;To get better insights in the system the overall capacities are moved up
      set space-left capacity
      set name item 0 current
      set label name
      set label-color white
      set onshore-distance item 1 current
      set offshore-distance item 2 current
      set capex-onshore item 4 current
      set capex-offshore item 5 current
      set time-to-build ceiling ((onshore-distance + offshore-distance) / 20) + 4 ;It takes 1 year to build a storage + 5% of the total distance
      set storage-capex onshore-distance * capex-onshore + offshore-distance * capex-offshore
      set storage-price storage-capex / capacity / [payback-time] of one-of ports ;To earn back the investment in "payback-time" years, the port wants x money per ton co2 stored.
    ]
    set i i + 1
  ]
  file-close
end


to go
  ;Stop the code when there is no available storages to be built anymore
  if count storages with [color = grey or color = blue] = 0 [stop]

  ;The industries capture co2
  ask industries[capture-co2]

  if any? storages with [color != grey][
  ;The industries get the choice to create a new capture-technology
  create-capture-technology
  ]

;The port receives their subsidy for the next quarter which is also added to the KPI: total subsidy
  ask one-of ports[
    set budget budget + [available-budget-port] of one-of governments
    set total-subsidy-port total-subsidy-port + [available-budget-port] of one-of governments
  ]

  send-co2-to-storages
  create-storage-if-needed
  find-connections-with-existing-storages


  ;Some color effects to visualize the state of the system as a whole
  recolor-storages
  recolor-industries

  update-variables

  tick
  ;Stop the code when there is no available data anymore
  if ticks > 120[stop]
end


;Depending on the amount of oil used, an industry produces co2, they capture a part of this co2 based on their expected costs for storing and capturing.
to capture-co2
  ask industries with[capture-technology? = True][
    let emitting-costs (created-co2 * co2-price)

    ;the costs for capturing co2 exist of electricity costs and storage
    let electricity-costs (created-co2 * electricity-price * capture-opex-electricity)
    let lowest-storage-price [storage-price] of min-one-of storages with [color != grey][storage-price]
    let storing-costs (created-co2 * lowest-storage-price) + (storage-opex * created-co2)
    let capture-costs electricity-costs + storing-costs
    ;If the expected costs for emitting are higher than the expected costs for capturing and storing the co2, an industry will choose to capture their co2.
    if  emitting-costs > capture-costs[
      set captured-co2 min list created-co2 capture-capacity
  ]]
 end

to create-capture-technology
  let lowest-storage-price [storage-price] of min-one-of storages with [color != grey][storage-price]
  let subsidy [available-budget-industries] of one-of governments / count industries
  ;if industries expect capturing co2 to be cheaper than emmitting co2, even with the investment of a capture technology, they will build one
  ask industries[
    let potential-capture-amount min list created-co2 max-capture
    ;Marginal means that if an industry already has a capture technology, only the improvement will benefit them
    let marginal-capture potential-capture-amount - capture-capacity
    let emitting-costs (marginal-capture * co2-price)
    let electricity-costs (marginal-capture * electricity-price * capture-opex-electricity)
    let storage-costs (marginal-capture * lowest-storage-price) + (storage-opex * marginal-capture) + connection-to-storage-price
    let building-costs ((capture-capex * max-capture) - subsidy) / payback-period
    let capturing-costs electricity-costs + storage-costs + building-costs

    if emitting-costs > capturing-costs[
      set capture-technology? True
      set capture-capacity potential-capture-amount
      set label round capture-capacity
      set label-color blue
      set total-subsidy-industries total-subsidy-industries + subsidy
  ]]
end

to create-storage-if-needed
  ;Finds the location for the storage that will be built next
  let next-storage min-one-of storages with [color = grey][who]
  let needs-new-storage? False
  ;if no storage exists that has room for co2, a new storage is needed.
  if count storages with [color != red and color != grey] = 0[
    set needs-new-storage? True
  ]
  ;If no storages are being built at the moment and no storages exist that can still connect to industries, a new storage is needed
  if count storages with [color = blue] = 0 and count storages with [space-left > 0 and extensible? = True] = 0[
    set needs-new-storage? True
  ]

  ;Makes a list of industries that have captured co2 but can not store this right now
  let willing-industries industries with [captured-co2 > 0]
  ;If no storage exists that has space left, and the port has enough money, a new storage will be created.
  ;Even if the storage will be in the cheaper fixed form, enough money for the extensible one has to be available.
  if needs-new-storage? = True and [budget] of one-of ports >= [storage-capex] of next-storage[
   ask ports[
      ;The new storage will be extensible if the government expects that the storage will not be full from the start. This makes sure all space is used.
      ifelse (sum [captured-co2] of willing-industries - sum [stored-co2] of willing-industries) < [capacity] of next-storage[
        set extensible-willing? True
      ]
      [set extensible-willing? False]
      create-storage extensible-willing?
    ]
  ]
end

to create-storage[extensible-willing]
  ;When the port decides a new storage should be built, the color of the next storage in line becomes green, and it now takes x years before the storage/pipeline is built.
  let new-storage min-one-of storages with [color = grey][who]
  ask new-storage [
    set color blue
    set extensible? extensible-willing
    if extensible? = False[
      set storage-capex storage-capex * 0.7
    ]
    set available? False
    ask one-of ports[
      set budget budget - [storage-capex] of new-storage]
  ]


  ask industries[
    set sendable-co2 captured-co2 - stored-co2
  ]
  ;When a new storage is built, the industries are asked to connect to it. When the storage is fixed, this is the last chance for connecting.
  let willing-industries industries with [sendable-co2 > 0]
  while [[space-left] of new-storage > 0 and count willing-industries > 0][
    let current-industry one-of willing-industries
    let sent-co2 min list ([sendable-co2] of current-industry) ([space-left] of new-storage)
    connect-to-new-storage current-industry sent-co2
    ask current-industry[
      set sendable-co2 sendable-co2 - sent-co2
    ]
    ask new-storage[
      set space-left space-left - sent-co2
    ]
    set willing-industries willing-industries with [sendable-co2 > 0]
  ]
end

to connect-to-new-storage[current-industry amount-of-co2]
  ;When a new storage is built all of the industries are asked if they would like to join.
  ask current-industry
  [
    let new-storage max-one-of storages with [color = blue][who]
    create-link-with new-storage[
      set connected-storage new-storage
      set connected-industry current-industry
      set shape "stripes"
      set co2-stream amount-of-co2
      set storage-link-price [storage-price] of connected-storage * co2-stream + storage-opex * co2-stream + connection-to-storage-price
    ]
  ]
end

to find-connections-with-existing-storages
;calculate how much co2 the industries want to share with a storage they are not connected to right now.
  ask industries[
    set sendable-co2 captured-co2 - stored-co2
  ]
  let willing-industries industries with [sendable-co2 > 0]
  ;Only storages that are extensible and have space left are taken into account
  let willing-storages storages with [space-left > 0 and extensible? = True and color != grey]
  ;Keep on connecting industries to storages while not all space is used and industries have co2 to share.
  while [count willing-storages > 0 and count willing-industries > 0][
    let current-storage min-one-of willing-storages[storage-price]
    let current-industry one-of willing-industries
    let sent-co2 min list ([sendable-co2] of current-industry) ([space-left] of current-storage)
    connect-to-existing-storage current-industry current-storage sent-co2
    ask current-industry[
      set sendable-co2 sendable-co2 - sent-co2
    ]
    ask current-storage[
      set space-left space-left - sent-co2
    ]
    set willing-storages willing-storages with [space-left > 0]
    set willing-industries willing-industries with [sendable-co2 > 0]
]
end

to connect-to-existing-storage[current-industry existing-storage amount-of-co2]
  ask current-industry
  [
   create-link-with existing-storage[
      set connected-storage existing-storage
      set connected-industry current-industry
      set shape "stripes"
      set co2-stream amount-of-co2
      set storage-link-price [storage-price] of connected-storage * co2-stream + storage-opex * co2-stream + connection-to-storage-price
    ]
  ]
end

to send-co2-to-storages
  ;in order to determine what the industries pay to the port, we take the links they have and they will divide their captured CO2 as cheaply as possible over the links. All CO2 that is left is emitted.
  ask industries[
    set stored-co2 (sum [co2-stream] of my-links with [color = green])
    set emitted-co2 created-co2 - stored-co2
  ]
  ask one-of ports[
    set budget budget + sum [storage-link-price] of links with [color = green]
    ]
  ask storages[
    set space-left capacity
    set space-left round (space-left - sum [co2-stream] of my-links)
  ]
end

to recolor-storages
  ;The storages are recolored depending on how full they are.
  ask storages with [available? = True][
    let fullness (capacity - space-left) / capacity
    if fullness < 0.33[
      set color green
    ]
    if fullness >= 0.33 and fullness < 0.66[
      set color yellow
    ]
    if fullness >= 0.66 and fullness < 1.00[
      set color orange
    ]
    if fullness = 1.00[
      set color red
      set available? False
    ]
  ]
end

to recolor-industries
  ;The industries are recolored based on how much co2 they capture and how much co2 they emit.
  ask industries
  [
    let co2-neutrality (emitted-co2 - stored-co2)
    if co2-neutrality <= 0[
      set color green
    ]
    if co2-neutrality > 0[
        set color red
    ]
  ]
end

to update-variables
  ;Update the globals
  set electricity-price electricity-price * 0.95
  set total-co2 total-emitted-co2 + total-stored-co2
  if ticks mod 4 = 0[
    set year year + 1
    set max-capture max-capture * 1.1
    set capture-capex capture-capex * 0.9
  ]
  ;Every year some of the globals are changed which is done in this function.
  set co2-price item year co2-price-list
  ;Update the building time that is left for the storages under construction.
  ask storages with [color = blue][
    set time-to-build time-to-build - 1
    if time-to-build = 0[
      set color green
      set available? True
    ]
   ]
  ;Links are created before a storage can be used. That is why in the model only links that are green will be taken into account (these links connect available storages)
  ask links[
    if [color] of connected-storage != blue[
      set color green
    ]
  ]
  ;Calculate the KPI's
  set total-co2 total-co2 + sum [created-co2] of industries
  set total-stored-co2 total-stored-co2 + sum [stored-co2] of industries
  set total-emitted-co2 total-emitted-co2 + sum [emitted-co2] of industries
  set co2-emitted-per-year sum [emitted-co2] of industries
  set co2-stored-per-year sum [stored-co2] of industries
  set total-electricity-use total-electricity-use + (sum [captured-co2] of industries) * capture-opex-electricity
  end
@#$#@#$#@
GRAPHICS-WINDOW
251
10
780
540
-1
-1
15.8
1
10
1
1
1
0
0
0
1
0
32
0
32
1
1
1
ticks
30.0

BUTTON
15
20
81
53
setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
16
60
79
93
Go
Go
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
83
60
146
93
Go
Go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

SLIDER
11
140
202
173
percentage-port
percentage-port
0
100
50.0
1
1
%
HORIZONTAL

SLIDER
12
177
202
210
number-of-industries
number-of-industries
0
50
25.0
1
1
NIL
HORIZONTAL

MONITOR
805
17
930
62
Total-CO2 produced
total-co2
2
1
11

MONITOR
806
73
930
118
Total CO2 emitted
total-emitted-co2
2
1
11

MONITOR
806
129
927
174
Total CO2 stored
total-stored-co2
2
1
11

MONITOR
808
193
926
238
Port current budget
[budget] of one-of ports
2
1
11

MONITOR
808
249
925
294
Year
2018 + year
0
1
11

PLOT
969
18
1169
168
Co2 destinations
ticks (quarters)
Amount of co2
0.0
125.0
0.0
100000.0
true
false
"" ""
PENS
"total-co2" 1.0 0 -16777216 true "" "plot total-co2"
"total-emissions" 1.0 0 -2674135 true "" "plot total-emitted-co2"
"total-storage" 1.0 0 -13840069 true "" "plot total-stored-co2"

PLOT
973
178
1173
328
CO2 per year
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"emissions" 1.0 0 -2674135 true "" "plot co2-emitted-per-year"
"storage" 1.0 0 -13840069 true "" "plot co2-stored-per-year"

MONITOR
807
305
932
350
total-subsidy-industries
total-subsidy-industries
2
1
11

MONITOR
807
359
919
404
total-subsidy-port
total-subsidy-port
2
1
11

MONITOR
807
412
935
457
total-costs-for-storage
sum [storage-link-price] of links with [color = green]
2
1
11

MONITOR
808
466
928
511
NIL
total-electricity-use
2
1
11

PLOT
982
382
1182
532
total-electricity-use
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot total-electricity-use"

SLIDER
12
102
203
135
subsidiy-total
subsidiy-total
50
200
150.0
1
1
million euro / year
HORIZONTAL

SLIDER
11
214
203
247
capacity-multiplicative
capacity-multiplicative
1
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
11
251
203
284
max-oil-demand
max-oil-demand
2
20
10.0
1
1
Mt/yr
HORIZONTAL

SLIDER
11
289
205
322
electricity-price-slider
electricity-price-slider
1
100
10.0
1
1
eur / MWh
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model is about the Volkswagen-scandal. Some factories used dishonest software in their cars. Because of this software, the cars seemed to be more environmental friendly than they actually were. Volkswagen used this to make more profit. This model is about some circumstances in which honest factories can turn into dishonest factories.


## HOW IT WORKS

The model consists of checkers  and three types of factories: honest (green colour), dishonest (yellow colour) and caught (red colour). All the factories  together produce and sell 1000 cars every tick. The honest factories sell them for 2000 euro per car. A dishonest factory however, sells a car for 2000 euro plus the extra profit.
The checkers move randomly around the world. If a checker comes within a 0.5 patch radius of a factory, it checks the state of the factory. If a factory was using the dishonest software, the factory gets caught by the checker. The caught factory now has to stop producing cars for 25 ticks. Note that the total production of all the factories is now reduced to less than 1000 cars. If the 25 ticks of being punished are over, the factory turns into an honest factory again and resumes its production.
An honest factory can turn into a dishonest factory. To let this occur, two things need to happen. Firstly, the number of caught factories in its radius divided by the total number of factories in its radius has to be less than the (adjustable) dishonest-in-radius. Secondly, a random number has to be less than the extra profit divided by two.

Note that the stimulation will stop when 75% of the factories are honest.

## HOW TO USE IT

Click on the setup button to setup the world with the (honest) factories and the checkers. Press the go of the go once button to start the stimulation.

You can use the slider NUMBER-OF-FACTORIES to setup the number of factories, the slider NUMBER-OF-CHECKERS to setup the number of checkers and the slider INITIAL-PERCENTAGE-DISHONEST to setup the initial percentage of dishonest factories.

The slider EXTRA-PROFIT can be used to set the percentage of extra profit a dishonest factory makes per car. The slider DISHONEST-IN-RADIUS sets the percentage of factories in the 5-patch-radius which are caught, to let a factory turn from an honest factory into a dishonest factory.

## THINGS TO NOTICE

The stimulation will stop when 75% of the factories are honest. Notice that the stimulation will stop when the extra-profit is set to 0 or the dishonest-in-radius is set to 0. How fast the stimulation stops, depends on the initial-percentage-dishonest.


## THINGS TO TRY

The parameter with the most influence are the extra-profit, the number of checkers and the dishonest-in-radius. So, when exploring the model, try to vary these two the most.



## EXTENDING THE MODEL

At the moment, the checkers move randomly around the world. In reality the checkers may choose the soon-to-be checked factory at random,  but when chosen, the checker will take the fastest route to the factory. You can try to improve the model by implementing this extension.

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

building institution
false
0
Rectangle -7500403 true true 0 60 300 270
Rectangle -16777216 true false 130 196 168 256
Rectangle -16777216 false false 0 255 300 270
Polygon -7500403 true true 0 60 150 15 300 60
Polygon -16777216 false false 0 60 150 15 300 60
Circle -1 true false 135 26 30
Circle -16777216 false false 135 25 30
Rectangle -16777216 false false 0 60 300 75
Rectangle -16777216 false false 218 75 255 90
Rectangle -16777216 false false 218 240 255 255
Rectangle -16777216 false false 224 90 249 240
Rectangle -16777216 false false 45 75 82 90
Rectangle -16777216 false false 45 240 82 255
Rectangle -16777216 false false 51 90 76 240
Rectangle -16777216 false false 90 240 127 255
Rectangle -16777216 false false 90 75 127 90
Rectangle -16777216 false false 96 90 121 240
Rectangle -16777216 false false 179 90 204 240
Rectangle -16777216 false false 173 75 210 90
Rectangle -16777216 false false 173 240 210 255
Rectangle -16777216 false false 269 90 294 240
Rectangle -16777216 false false 263 75 300 90
Rectangle -16777216 false false 263 240 300 255
Rectangle -16777216 false false 0 240 37 255
Rectangle -16777216 false false 6 90 31 240
Rectangle -16777216 false false 0 75 37 90
Line -16777216 false 112 260 184 260
Line -16777216 false 105 265 196 265

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

container
false
0
Rectangle -7500403 false false 0 75 300 225
Rectangle -7500403 true true 0 75 300 225
Line -16777216 false 0 210 300 210
Line -16777216 false 0 90 300 90
Line -16777216 false 150 90 150 210
Line -16777216 false 120 90 120 210
Line -16777216 false 90 90 90 210
Line -16777216 false 240 90 240 210
Line -16777216 false 270 90 270 210
Line -16777216 false 30 90 30 210
Line -16777216 false 60 90 60 210
Line -16777216 false 210 90 210 210
Line -16777216 false 180 90 180 210

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

factory
false
0
Rectangle -7500403 true true 76 194 285 270
Rectangle -7500403 true true 36 95 59 231
Rectangle -16777216 true false 90 210 270 240
Line -7500403 true 90 195 90 255
Line -7500403 true 120 195 120 255
Line -7500403 true 150 195 150 240
Line -7500403 true 180 195 180 255
Line -7500403 true 210 210 210 240
Line -7500403 true 240 210 240 240
Line -7500403 true 90 225 270 225
Circle -1 true false 37 73 32
Circle -1 true false 55 38 54
Circle -1 true false 96 21 42
Circle -1 true false 105 40 32
Circle -1 true false 129 19 42
Rectangle -7500403 true true 14 228 78 270

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

i beam
false
0
Polygon -7500403 true true 165 15 240 15 240 45 195 75 195 240 240 255 240 285 165 285
Polygon -7500403 true true 135 15 60 15 60 45 105 75 105 240 60 255 60 285 135 285

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

person police
false
0
Polygon -1 true false 124 91 150 165 178 91
Polygon -13345367 true false 134 91 149 106 134 181 149 196 164 181 149 106 164 91
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -13345367 true false 120 90 105 90 60 195 90 210 116 158 120 195 180 195 184 158 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Polygon -13345367 true false 150 26 110 41 97 29 137 -1 158 6 185 0 201 6 196 23 204 34 180 33
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Rectangle -16777216 true false 109 183 124 227
Rectangle -16777216 true false 176 183 195 205
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Polygon -1184463 true false 172 112 191 112 185 133 179 133
Polygon -1184463 true false 175 6 194 6 189 21 180 21
Line -1184463 false 149 24 197 24
Rectangle -16777216 true false 101 177 122 187
Rectangle -16777216 true false 179 164 183 186

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
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Percentage port" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-co2</metric>
    <metric>total-stored-co2</metric>
    <metric>total-emitted-co2</metric>
    <metric>total-subsidy-port</metric>
    <metric>total-subsidy-industries</metric>
    <metric>total-electricity-use</metric>
    <enumeratedValueSet variable="max-oil-demand">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="electricity-price-slider">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="percentage-port" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="number-of-industries">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subsidiy-total">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-multiplicative">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Subsidy total" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-co2</metric>
    <metric>total-stored-co2</metric>
    <metric>total-emitted-co2</metric>
    <metric>total-subsidy-port</metric>
    <metric>total-subsidy-industries</metric>
    <metric>total-electricity-use</metric>
    <enumeratedValueSet variable="max-oil-demand">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="electricity-price-slider">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percentage-port">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-industries">
      <value value="25"/>
    </enumeratedValueSet>
    <steppedValueSet variable="subsidiy-total" first="0" step="25" last="200"/>
    <enumeratedValueSet variable="capacity-multiplicative">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="oil demand" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-co2</metric>
    <metric>total-stored-co2</metric>
    <metric>total-emitted-co2</metric>
    <metric>total-subsidy-port</metric>
    <metric>total-subsidy-industries</metric>
    <metric>total-electricity-use</metric>
    <enumeratedValueSet variable="max-oil-demand">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="electricity-price-slider">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percentage-port">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-industries">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subsidiy-total">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-multiplicative">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="electricity price" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-co2</metric>
    <metric>total-stored-co2</metric>
    <metric>total-emitted-co2</metric>
    <metric>total-subsidy-port</metric>
    <metric>total-subsidy-industries</metric>
    <metric>total-electricity-use</metric>
    <enumeratedValueSet variable="max-oil-demand">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="electricity-price-slider">
      <value value="1"/>
      <value value="10"/>
      <value value="50"/>
      <value value="75"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percentage-port">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-industries">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subsidiy-total">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-multiplicative">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Number of industries" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-co2</metric>
    <metric>total-stored-co2</metric>
    <metric>total-emitted-co2</metric>
    <metric>total-subsidy-port</metric>
    <metric>total-subsidy-industries</metric>
    <metric>total-electricity-use</metric>
    <enumeratedValueSet variable="max-oil-demand">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="electricity-price-slider">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percentage-port">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-industries">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subsidiy-total">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-multiplicative">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="capacity" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-co2</metric>
    <metric>total-stored-co2</metric>
    <metric>total-emitted-co2</metric>
    <metric>total-subsidy-port</metric>
    <metric>total-subsidy-industries</metric>
    <metric>total-electricity-use</metric>
    <enumeratedValueSet variable="max-oil-demand">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="electricity-price-slider">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percentage-port">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-industries">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subsidiy-total">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-multiplicative">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
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

stripes
0.0
-0.2 0 0.0 1.0
0.0 1 4.0 4.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
