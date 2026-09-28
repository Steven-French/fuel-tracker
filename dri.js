/* NDLZ nutrient targets: reference tables (data only; read by index.html).

   Sources
   - Dietary Reference Intakes (RDA / AI / UL) by life-stage group, National Academies of Sciences, Engineering, and Medicine
     (Food and Nutrition Board), as tabulated by the NIH Office of Dietary Supplements:
       https://ods.od.nih.gov/HealthInformation/nutrientrecommendations.aspx
       https://www.ncbi.nlm.nih.gov/books/NBK545442/  (DRI summary tables: vitamins, elements, macronutrients, ULs)
     Sodium and potassium use the 2019 NASEM update (AI + Chronic Disease Risk Reduction intake for sodium):
       https://ods.od.nih.gov/factsheets/Sodium-HealthProfessional/  https://ods.od.nih.gov/factsheets/Potassium-HealthProfessional/
     Essential amino acids: NASEM Macronutrient DRI report (2002/2005), adult RDA in mg per kg body weight per day.
   - FDA Daily Values used on US Nutrition Facts labels (adults and children 4+), 21 CFR 101.9(c)(8)(iv) and (c)(9):
       https://www.fda.gov/food/nutrition-facts-label/daily-value-nutrition-and-supplement-facts-labels
   - Limits not set by a DRI: saturated fat and added sugars < 10% of calories (Dietary Guidelines for Americans 2020–2025),
     caffeine 400 mg/day for healthy adults (FDA).

   Units match the app's nutrient registry: vitamin A µg RAE, D µg, E mg alpha-tocopherol, K µg, folate µg DFE, niacin mg,
   copper mg, fluoride mg, chromium/iodine/molybdenum/selenium/biotin/B12 µg, fiber and fatty acids g, everything else mg.
   ULs are left out where the NASEM UL applies only to supplements/fortificants or preformed forms (vitamin A total, vitamin E,
   niacin, folate, magnesium), since the app counts nutrients from food. Pregnancy and lactation are not modelled. */
(function(){
  // Age bands (years, inclusive). Each value array below has one entry per band, in this order.
  var BANDS = [[9,13],[14,18],[19,30],[31,50],[51,70],[71,200]];
  var same = function(v){ return [v,v,v,v,v,v]; };
  // key: [kind, male by band, female by band]
  var REC = {
    vitA:    ['RDA', [600,900,900,900,900,900],      [600,700,700,700,700,700]],
    vitC:    ['RDA', [45,75,90,90,90,90],            [45,65,75,75,75,75]],
    vitD:    ['RDA', [15,15,15,15,15,20],            [15,15,15,15,15,20]],
    vitE:    ['RDA', [11,15,15,15,15,15],            [11,15,15,15,15,15]],
    vitK:    ['AI',  [60,75,120,120,120,120],        [60,75,90,90,90,90]],
    b1:      ['RDA', [0.9,1.2,1.2,1.2,1.2,1.2],      [0.9,1.0,1.1,1.1,1.1,1.1]],
    b2:      ['RDA', [0.9,1.3,1.3,1.3,1.3,1.3],      [0.9,1.0,1.1,1.1,1.1,1.1]],
    b3:      ['RDA', [12,16,16,16,16,16],            [12,14,14,14,14,14]],
    b5:      ['AI',  [4,5,5,5,5,5],                  [4,5,5,5,5,5]],
    b6:      ['RDA', [1.0,1.3,1.3,1.3,1.7,1.7],      [1.0,1.2,1.3,1.3,1.5,1.5]],
    b7:      ['AI',  [20,25,30,30,30,30],            [20,25,30,30,30,30]],
    folate:  ['RDA', [300,400,400,400,400,400],      [300,400,400,400,400,400]],
    b12:     ['RDA', [1.8,2.4,2.4,2.4,2.4,2.4],      [1.8,2.4,2.4,2.4,2.4,2.4]],
    choline: ['AI',  [375,550,550,550,550,550],      [375,400,425,425,425,425]],
    ca:      ['RDA', [1300,1300,1000,1000,1000,1200],[1300,1300,1000,1000,1200,1200]],
    cr:      ['AI',  [25,35,35,35,30,30],            [21,24,25,25,20,20]],
    cu:      ['RDA', [0.7,0.89,0.9,0.9,0.9,0.9],     [0.7,0.89,0.9,0.9,0.9,0.9]],
    fl:      ['AI',  [2,3,4,4,4,4],                  [2,3,3,3,3,3]],
    iod:     ['RDA', [120,150,150,150,150,150],      [120,150,150,150,150,150]],
    fe:      ['RDA', [8,11,8,8,8,8],                 [8,15,18,18,8,8]],
    mg:      ['RDA', [240,410,400,420,420,420],      [240,360,310,320,320,320]],
    mn:      ['AI',  [1.9,2.2,2.3,2.3,2.3,2.3],      [1.6,1.6,1.8,1.8,1.8,1.8]],
    mo:      ['RDA', [34,43,45,45,45,45],            [34,43,45,45,45,45]],
    phos:    ['RDA', [1250,1250,700,700,700,700],    [1250,1250,700,700,700,700]],
    k:       ['AI',  [2500,3000,3400,3400,3400,3400],[2300,2300,2600,2600,2600,2600]],
    se:      ['RDA', [40,55,55,55,55,55],            [40,55,55,55,55,55]],
    na:      ['AI',  [1200,1500,1500,1500,1500,1500],[1200,1500,1500,1500,1500,1500]],
    zn:      ['RDA', [8,11,11,11,11,11],             [8,9,8,8,8,8]],
    fiber:   ['AI',  [31,38,38,38,30,30],            [26,26,25,25,21,21]],
    omega3:  ['AI',  [1.2,1.6,1.6,1.6,1.6,1.6],      [1.0,1.1,1.1,1.1,1.1,1.1]],   // alpha-linolenic acid
    omega6:  ['AI',  [12,16,17,17,14,14],            [10,11,12,12,11,11]]          // linoleic acid
  };
  // Tolerable Upper Intake Levels (same for both sexes), by band. Sodium uses the CDRR (reduce intake if above).
  var UL = {
    vitC: [1200,1800,2000,2000,2000,2000],
    vitD: same(100),
    b6:   [60,80,100,100,100,100],
    choline: [2000,3000,3500,3500,3500,3500],
    ca:   [3000,3000,2500,2500,2000,2000],
    cu:   [5,8,10,10,10,10],
    fl:   same(10),
    iod:  [600,900,1100,1100,1100,1100],
    fe:   [40,45,45,45,45,45],
    mn:   [6,9,11,11,11,11],
    mo:   [1100,1700,2000,2000,2000,2000],
    phos: [4000,4000,4000,4000,4000,3000],
    se:   [280,400,400,400,400,400],
    na:   [1800,2300,2300,2300,2300,2300],
    zn:   [23,34,40,40,40,40]
  };
  // Adult (19+) essential amino acid RDA, mg per kg body weight per day (NASEM 2002/2005).
  var AMINO_PER_KG = {his:14, ile:19, leu:42, lys:38, thr:20, trp:5, val:24};
  // FDA Daily Values (adults and children 4+). Sodium, saturated fat, cholesterol and added sugars are "less than" limits.
  var FDA = {
    vitA:900, vitC:90, vitD:20, vitE:15, vitK:120, b1:1.2, b2:1.3, b3:16, b5:5, b6:1.7, b7:30, folate:400, b12:2.4, choline:550,
    ca:1300, cr:35, cu:0.9, iod:150, fe:18, mg:420, mn:2.3, mo:45, phos:1250, k:4700, se:55, zn:11,
    fiber:28, protein:50, fat:78, carbs:275
  };
  var FDA_LIMIT = {na:2300, satFat:20, chol:300, addedSugar:50};
  window.NDLZ_DRI = {BANDS:BANDS, REC:REC, UL:UL, AMINO_PER_KG:AMINO_PER_KG, FDA:FDA, FDA_LIMIT:FDA_LIMIT,
    CHOL_LIMIT:300, CAFFEINE_LIMIT:400, PCT_KCAL_LIMIT:{satFat:[0.10,9], addedSugar:[0.10,4]},
    SOURCES:{dri:'NIH ODS / National Academies DRIs (RDA, AI, UL)', fda:'FDA Daily Values (Nutrition Facts label, adults 4+)'}};
})();
