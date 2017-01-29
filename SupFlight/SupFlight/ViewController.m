//
//  ViewController.m
//  SupFlight
//
//  Created by Local Administrator on 08/06/14.
//  Copyright (c) 2014 Jordan. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>

#import <sqlite3.h>

#define START @"Start"
#define STOP @"Stop"
#define RESET @"Reset"

@interface ViewController ()

@property (strong, nonatomic) IBOutlet UILabel *timeLabel;
@property (strong, nonatomic) IBOutlet UILabel *startLabel;
@property (strong, nonatomic) IBOutlet UILabel *endLabel;
@property (strong, nonatomic) IBOutlet UILabel *durationLabel;
@property (strong, nonatomic) IBOutlet UIButton *actionButton;

@property (strong, nonatomic) NSDateFormatter *df;
@property (strong, nonatomic) NSDate *startDate;
@property (strong, nonatomic) NSDate *endDate;
@property (strong, nonatomic) NSString *duration;

@property (strong, nonatomic) NSString *databasePath;
@property (nonatomic) sqlite3 *flightDB;

@property (strong, nonatomic) CLLocation *userLocation;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) NSString *icaoCode;

- (IBAction)startFlight:(id)sender;
- (void)updateClock:(NSTimer *)timer;
- (void)createTable;
- (void)injectData;
- (void)findNearestLoc:(CLLocation *)loc;
- (void)saveData;
- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Create the SQLite database
	[self createTable];
    
    // Création du timer qui va appeler la méthode de mise à jour de timeLabel toutes les secondes
	[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateClock:) userInfo:nil repeats:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Gestion du démarrage et de l'arrêt du compteur
- (IBAction)startFlight:(id)sender {
    if ([self.actionButton.titleLabel.text isEqualToString:RESET]) {
		self.startLabel.text = @"";
		self.endLabel.text = @"";
		self.durationLabel.text = @"";
        [self.actionButton setTitle:START forState:UIControlStateNormal];
	}
	else if ([self.actionButton.titleLabel.text isEqualToString:START]) {
        [self CurrentLocationIdentifier];
        [self.actionButton setTitle:STOP forState:UIControlStateNormal];
	}
	else {
		[self setEndDate:_icaoCode withTime:[NSDate date]];
		NSTimeInterval ti = [self.endDate timeIntervalSinceDate:self.startDate];
        NSString *time = [self stringFromTimeInterval:ti];
        _duration = time;
		self.durationLabel.text = time;
        [self.actionButton setTitle:RESET forState:UIControlStateNormal];
        [self saveData];
	}
}

#pragma mark - Mise à jour de l'heure
- (void)updateClock:(NSTimer *)timer
{
	self.timeLabel.text = [self.df stringFromDate:[NSDate date]];
}

#pragma mark - Getter du NSDateFormatter
- (NSDateFormatter *)df {
	if (!_df) {
		_df = [[NSDateFormatter alloc] init];
		_df.dateFormat = @"HH:mm:ss";
	}
	
	return _df;
}

#pragma mark - Setters pour mettre à jour les labels on fonction de la date qui lui correspond
- (void)setStartDate:(NSString *)icao withTime:(NSDate *)startDate
{
	_startDate = startDate;
	self.startLabel.text = [NSString stringWithFormat:@"Departure: %@, %@", icao, [self.df stringFromDate:_startDate]];
}

- (void)setEndDate:(NSString *)icao withTime:(NSDate *)endDate
{
	_endDate = endDate;
	self.endLabel.text = [NSString stringWithFormat:@"Arrival: %@, %@", icao, [self.df stringFromDate:_endDate]];
}

#pragma mark - Create the SQLite databse
- (void) createTable
{
    NSString *docsDir;
    NSArray *dirPaths;
    
    // Get the documents directory
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    docsDir = dirPaths[0];
    
    // Build the path to the database file
    _databasePath = [[NSString alloc] initWithString: [docsDir stringByAppendingPathComponent:@"flight.sqlite"]];
    
    NSFileManager *filemgr = [NSFileManager defaultManager];
    
    if ([filemgr fileExistsAtPath: _databasePath ] == NO)
    {
        const char *dbpath = [_databasePath UTF8String];
        
        if (sqlite3_open(dbpath, &_flightDB) == SQLITE_OK)
        {
            char *errMsg;
            const char *sql_stmt = "CREATE TABLE IF NOT EXISTS FLIGHTS (ID INTEGER PRIMARY KEY AUTOINCREMENT, NAME TEXT, LAT REAL, LONG REAL)";
            
            const char *sql_stmt_flight = "CREATE TABLE IF NOT EXISTS FLIGHTS_DONE (ID INTEGER PRIMARY KEY AUTOINCREMENT, DATE TEXT, ICAO TEXT, DEP_HOUR TEXT, ARI_HOUR TEXT, DURATION TEXT)";
            
            if (sqlite3_exec(_flightDB, sql_stmt, NULL, NULL, &errMsg) != SQLITE_OK)
                NSLog(@"Failed to create table flights");
            
            if (sqlite3_exec(_flightDB, sql_stmt_flight, NULL, NULL, &errMsg) != SQLITE_OK)
                NSLog(@"Failed to create table flights_done");
            
            sqlite3_close(_flightDB);
            [self injectData];
        }
        else
            NSLog(@"Failed to open/create database");
    }
}

#pragma mark - Insert all the flight in the SQLite database
- (void) injectData
{
    sqlite3_stmt *statement;
    const char *dbpath = [_databasePath UTF8String];
    
    if (sqlite3_open(dbpath, &_flightDB) == SQLITE_OK)
    {        
        // Airport database
        const char *insert_stmt = "INSERT INTO FLIGHTS (name, lat, long) VALUES (\"LFAB - Aerodrome de Dieppe - Saint-Aubin\", 49.8825, 1.08527777778), (\"LFAC - Aeroport de Calais - Dunkerque\", 50.9608333333, 1.95138888889), (\"LFAD - Aerodrome de Compiegne - Margny\", 49.4344444444, 2.80611111111), (\"LFAE - Aerodrome d'Eu - Mers - Le Treport\", 50.0691666667, 1.42666666667), (\"LFAF - Aerodrome de Laon - Chambry\", 49.5958333333, 3.63166666667), (\"LFAG - Aeroport de Peronne - Saint-Quentin\", 49.8688888889, 3.02972222222), (\"LFAI - Aeroport de Nangis Les Loges\", 48.5958333333, 3.01416666667), (\"LFAJ - Aeroport d'Argentan\", 48.7105555556, 0.00388888888889), (\"LFAK - Aerodrome de Dunkerque - Les Moeres\", 51.0405555556, 2.55027777778), (\"LFAL - Aerodrome de La Fleche - Thoree-les-Pins\", 47.6941666667, 0.00333333333333), (\"LFAM - Aeroport de Berck sur Mer\", 50.4230555556, 1.59194444444), (\"LFAO - Aeroport de Bagnoles-de-l'Orne - Couterne\", 48.5455555556, 0.383611111111), (\"LFAP - Aerodrome de Rethel - Perthes\", 49.4819444444, 4.36472222222), (\"LFAQ - Aerodrome d'Albert - Bray\", 49.9725, 2.69138888889), (\"LFAR - Aerodrome de Montdidier\", 49.6730555556, 2.56916666667), (\"LFAS - Aerodrome de Falaise Mont d'Eraines\", 48.9272222222, 0.144722222222), (\"LFAT - Aeroport du Touquet Cote d'Opale\", 50.5147222222, 1.6275), (\"LFAU - Aerodrome de Vauville\", 49.6241666667, 1.82916666667), (\"LFAV - Aeroport de Valenciennes - Denain\", 50.3247222222, 3.46555555556), (\"LFAW - Aerodrome de Villerupt\", 49.4113888889, 5.89055555556), (\"LFAX - Aeroport de Mortagne au Perche\", 48.5402777778, 0.533888888889), (\"LFAY - Aeroport d'Amiens - Glisy\", 49.8730555556, 2.38694444444), (\"LFBA - Aeroport Agen - La Garenne\", 44.1747222222, 0.590555555556), (\"LFBC - Base aerienne de Cazaux\", 44.5347222222, 1.13138888889), (\"LFBD - Aeroport de Bordeaux - Merignac\", 44.8286111111, 0.715277777778), (\"LFBE - Aeroport Bergerac - Roumaniere\", 44.8244444444, 0.520555555556), (\"LFBF - Aeroport de Francazal - Toulouse\", 43.5488888889, 1.35722222222), (\"LFBG - Base aerienne 709 Cognac - Chateaubernard\", 45.6583333333, 0.3175), (\"LFBH - Aeroport de La Rochelle - Ile de Re\", 46.1791666667, 1.19527777778), (\"LFBI - Aeroport de Poitiers - Biard\", 46.5875, 0.306666666667), (\"LFBJ - Aeroport de Saint-Junien Maryse Bastie\", 45.9033333333, 0.92), (\"LFBK - Aeroport de Montlucon Gueret\", 46.2261111111, 2.36277777778), (\"LFBL - Aeroport de Limoges Bellegarde\", 45.8608333333, 1.18027777778), (\"LFBM - Base aerienne 118 Mont de Marsan\", 43.9125, 0.508611111111), (\"LFBN - Aerodrome de Niort Souche\", 46.3133333333, 0.394444444444), (\"LFBO - Aeroport Toulouse Blagnac\", 43.635, 1.36777777778), (\"LFBP - Aeroport Pau Pyrenees\", 43.38, 0.418611111111), (\"LFBR - Aerodrome de Muret - Lherm\", 43.4491666667, 1.26361111111), (\"LFBS - Aeroport de Biscarrosse - Parentis\", 44.3694444444, 1.13055555556), (\"LFBT - Aeroport de Tarbes Lourdes Pyrenees\", 43.1855555556, 0.00277777777778), (\"LFBU - Aeroport international Angouleme - Cognac\", 45.7294444444, 0.219166666667), (\"LFBX - Aeroport Perigueux Bassillac\", 45.1975, 0.814166666667), (\"LFBY - Aeroport de Dax - Seyresse\", 43.6891666667, 1.06888888889), (\"LFBZ - Aeroport de Biarritz Bayonne Anglet (BBA)\", 43.4683333333, 1.53111111111), (\"LFCA - Aeroport de Chatellerault Targe\", 46.7813888889, 0.551944444444), (\"LFCB - Aeroport de Bagneres de Luchon\", 42.8, 0.6), (\"LFCC - Aeroport de Cahors - Lalbenque\", 44.3505555556, 1.47861111111), (\"LFCD - Aeroport d'Andernos les Bains\", 44.7561111111, 1.06333333333), (\"LFCE - Aeroport de Gueret - Saint-Laurent\", 46.1755555556, 1.95305555556), (\"LFCF - Aerodrome de Figeac - Livernon\", 44.6733333333, 1.78916666667), (\"LFCG - Aerodrome de Saint-Girons - Antichan\", 43.0088888889, 1.10444444444), (\"LFCH - Aeroport d'Arcachon - La Teste-de-Buch\", 44.5986111111, 1.11472222222), (\"LFCI - Aerodrome d'Albi - Le Sequestre\", 43.9133333333, 2.11666666667), (\"LFCJ - Aeroport de Jonzac - Neulles\", 45.4841666667, 0.421388888889), (\"LFCK - Aeroport de Castres - Mazamet\", 43.555, 2.29055555556), (\"LFCL - Aeroport de Toulouse - Lasbordes\", 43.5888888889, 1.49972222222), (\"LFCM - Aerodrome de Millau Larzac\", 43.9891666667, 3.18333333333), (\"LFCN - Aeroport de Nogaro\", 43.7697222222, 0.0327777777778), (\"LFCO - Aeroport d'Oloron - Herrere\", 43.1647222222, 0.560277777778), (\"LFCP - Aeroport de Pons - Avy\", 45.57, 0.515), (\"LFCQ - Aeroport de Graulhet - Montdragon\", 43.77, 2.00888888889), (\"LFCR - Aeroport de Rodez - Marcillac\", 44.4075, 2.48333333333), (\"LFCS - Aeroport de Bordeaux - Leognan - Saucats\", 44.7002777778, 0.595555555556), (\"LFCT - Aeroport de Thouars\", 46.9619444444, 0.152777777778), (\"LFCU - Aerodrome d'Ussel - Thalamy\", 45.5369444444, 2.42555555556), (\"LFCV - Aeroport de Villefranche de Rouergue\", 44.37, 2.02805555556), (\"LFCW - Aeroport de Villeneuve sur Lot\", 44.4002777778, 0.761111111111), (\"LFCX - Aeroport de Castelsarrasin - Moissac\", 44.0869444444, 1.12833333333), (\"LFCY - Aerodrome de Royan - Medis\", 45.6311111111, 0.975555555556), (\"LFCZ - Aeroport de Mimizan\", 44.1469444444, 1.16333333333), (\"LFDA - Aeroport d'Aire sur l'Adour\", 43.7094444444, 0.245277777778), (\"LFDB - Aeroport de Montauban\", 44.0275, 1.37833333333), (\"LFDC - Aeroport de Montendre - Marcillac\", 45.2744444444, 0.452222222222), (\"LFDE - Aeroport d'egletons\", 45.4213888889, 2.06888888889), (\"LFDF - Aeroport de Sainte-Foy la Grande\", 44.8536111111, 0.176666666667), (\"LFDG - Aeroport de Gaillac - Lisle -sur-Tarn\", 43.8838888889, 1.87555555556), (\"LFDH - Aeroport d'Auch Lamothe\", 43.6869444444, 0.6), (\"LFDI - Aerodrome de Libourne - Artigues-de-Lussac\", 44.985, 0.133611111111), (\"LFDJ - Aerodrome de Pamiers - Les Pujols\", 43.0905555556, 1.69583333333), (\"LFDK - Aeroport de Soulac sur Mer\", 45.495, 1.08222222222), (\"LFDL - Aeroport de Loudun\", 47.0372222222, 0.101388888889), (\"LFDM - Aeroport de Marmande - Virazeil\", 44.5011111111, 0.1975), (\"LFDN - Aeroport de Rochefort - Saint-Agnant\", 45.8894444444, 0.9825), (\"LFDP - Aeroport de Saint-Pierre d'Oleron\", 45.9591666667, 1.31611111111), (\"LFDQ - Aerodrome de Castelnau Magnoac\", 43.2794444444, 0.521666666667), (\"LFDR - Aeroport de La Reole - Floudes\", 44.5680555556, 0.0561111111111), (\"LFDS - Aeroport de Sarlat - Domme\", 44.7933333333, 1.24472222222), (\"LFDT - Aerodrome de Tarbes - Laloubere\", 43.2161111111, 0.0786111111111), (\"LFDU - Aeroport de Lesparre - Saint-Laurent de Medoc\", 45.1977777778, 0.882222222222), (\"LFDV - Aeroport de Couhe Verac\", 46.2727777778, 0.190555555556), (\"LFDW - Aeroport de Chauvigny\", 46.5836111111, 0.6425), (\"LFDX - Aeroport de Fumel - Montayral\", 44.4636111111, 1.00777777778), (\"LFDY - Aerodrome de Bordeaux - Yvrac\", 44.8772222222, 0.479166666667), (\"LFDZ - Aeroport Condat sur Vezere\", 0.0, 0.0), (\"LFEA - Aeroport de Belle Ile\", 47.3266666667, 3.18416666667), (\"LFEB - Aeroport de Dinan - Trelivan\", 48.4444444444, 2.10138888889), (\"LFEC - Aeroport d'Ouessant\", 48.4641666667, 5.06222222222), (\"LFED - Aeroport de Pontivy\", 48.0577777778, 2.9225), (\"LFEF - Aeroport d'Amboise - Dierre\", 47.3413888889, 0.9425), (\"LFEG - Aeroport d'Argenton sur Creuse\", 46.5969444444, 1.6025), (\"LFEH - Aerodrome d'Aubigny sur Nere\", 47.4805555556, 2.39416666667), (\"LFEI - Aeroport de Briare Chatillon\", 47.6144444444, 2.78194444444), (\"LFEJ - Aeroport de Chateauroux - Villers\", 46.8419444444, 1.62111111111), (\"LFEK - Aeroport d'Issoudun Le Fay\", 46.8886111111, 2.04138888889), (\"LFEL - Aeroport du Blanc\", 46.6208333333, 1.0875), (\"LFEM - Aeroport de Montargis - Vimory\", 47.9605555556, 2.68583333333), (\"LFEN - Aeroport de Tours - Sorigny\", 47.2675, 0.701111111111), (\"LFEP - Aerodrome de Pouilly - Maconge\", 47.2213888889, 4.56111111111), (\"LFEQ - Aeroport de Quiberon\", 47.4822222222, 3.1), (\"LFER - Aeroport de Redon - Bains-sur-Oust\", 47.6994444444, 2.03666666667), (\"LFES - Aeroport de Guiscriff - Scaer\", 48.0547222222, 3.66277777778), (\"LFET - Aeroport de Til Chatel\", 47.5475, 5.21194444444), (\"LFEU - Aeroport de Bar-le-Duc - Les Hauts-de-Chee\", 48.8683333333, 5.18583333333), (\"LFEV - Aerodrome de Gray - Saint-Adrien\", 47.4333333333, 5.62277777778), (\"LFEW - Aeroport de Saulieu - Liernais\", 47.2394444444, 4.26583333333), (\"LFEX - Aerodrome de Nancy - Azelot\", 48.5927777778, 6.24111111111), (\"LFEY - Aeroport de l'Ile d'Yeu\", 46.7186111111, 2.39111111111), (\"LFEZ - Aerodrome de Nancy - Malzeville\", 48.7244444444, 6.20777777778), (\"LFFB - Aerodrome de Buno - Bonnevaux\", 48.3511111111, 2.42555555556), (\"LFFC - Aerodrome de Mantes - Cherence\", 49.0788888889, 1.68972222222), (\"LFFD - Aerodrome de Saint-Andre de l'Eure\", 48.8986111111, 1.25055555556), (\"LFFE - Aerodrome d'Enghien - Moisselles\", 49.0463888889, 2.35305555556), (\"LFFG - Aerodrome de La Ferte-Gaucher\", 48.7558333333, 3.27666666667), (\"LFFH - Aerodrome de Chateau-Thierry - Belleau\", 49.0672222222, 3.35694444444), (\"LFFI - Aeroport d'Ancenis\", 47.4080555556, 1.1775), (\"LFFJ - Aerodrome de Joinville - Mussey\", 48.3861111111, 5.145), (\"LFFK - Aeroport de Fontenay le Comte\", 46.4413888889, 0.792777777778), (\"LFFL - Aerodrome de Bailleau - Armenonville\", 48.5158333333, 1.64), (\"LFFM - Aerodrome de Lamotte Beuvron\", 0.0, 0.0), (\"LFFN - Aeroport de Brienne le Chateau\", 48.4308333333, 4.4825), (\"LFFP - Aerodrome de Pithiviers\", 48.1572222222, 2.1925), (\"LFFQ - Aerodrome de La Ferte Alais\", 48.4977777778, 2.34333333333), (\"LFFR - Aerodrome de Bar sur Seine\", 48.0669444444, 4.41361111111), (\"LFFT - Aerodrome de Neufchateau Rouceux\", 48.3616666667, 5.72027777778), (\"LFFU - Aerodrome de Chateauneuf sur Cher\", 46.8711111111, 2.37694444444), (\"LFFV - Aerodrome de Vierzon - Mereau\", 47.1947222222, 2.06666666667), (\"LFFW - Aeroport de Montaigu - Saint-Georges\", 46.9330555556, 1.32555555556), (\"LFFX - Aerodrome de Tournus - Cuisery\", 46.5627777778, 4.97666666667), (\"LFFY - Aerodrome d'etrepagny\", 49.3061111111, 1.63861111111), (\"LFFZ - Aeroport de Sezanne - Saint-Remy\", 48.7105555556, 3.76416666667), (\"LFGA - Aerodrome de Colmar - Houssen\", 48.1102777778, 7.35916666667), (\"LFGB - Aerodrome de Mulhouse - Habsheim\", 47.7380555556, 7.43222222222), (\"LFGC - Aerodrome de Strasbourg - Neuhof\", 48.5544444444, 7.77805555556), (\"LFGD - Aerodrome d'Arbois\", 46.8533333333, 5.76), (\"LFGE - Aeroport d'Avallon\", 47.5030555556, 3.89944444444), (\"LFGF - Aeroport de Beaune Challanges\", 47.0111111111, 4.8975), (\"LFGG - Aeroport de Belfort - Chaux\", 47.7022222222, 6.8325), (\"LFGH - Aeroport de Cosne sur Loire\", 47.3605555556, 2.91944444444), (\"LFGI - Aeroport de Dijon - Darois\", 47.3869444444, 4.94805555556), (\"LFGJ - Aeroport de Dole - Tavaux\", 47.0427777778, 5.435), (\"LFGK - Aeroport de Joigny\", 47.995, 3.39194444444), (\"LFGL - Aeroport de Lons-le-Saunier - Courlaoux\", 46.6761111111, 5.47111111111), (\"LFGM - Aeroport de Montceau-les-Mines - Pouilloux\", 46.6041666667, 4.33388888889), (\"LFGN - Aeroport de Paray le Monial\", 46.4677777778, 4.135), (\"LFGO - Aeroport de Pont sur Yonne\", 48.2905555556, 3.25083333333), (\"LFGP - Aeroport de Saint-Florentin - Cheu\", 47.9822222222, 3.77833333333), (\"LFGQ - Aeroport de Semur en Auxois\", 47.4819444444, 4.34416666667), (\"LFGR - Aeroport de Doncourt les Conflans\", 49.1527777778, 5.93277777778), (\"LFGS - Aeroport de Longuyon - Villette\", 49.4844444444, 5.57277777778), (\"LFGT - Aeroport de Sarrebourg - Buhl\", 48.7188888889, 7.07944444444), (\"LFGU - Aeroport de Sarreguemines Neunkirch\", 49.1280555556, 7.10833333333), (\"LFGV - Aeroport de Thionville - Yutz\", 0.0, 0.0), (\"LFGW - Aerodrome de Verdun Le Rozelier\", 49.1222222222, 5.47083333333), (\"LFGX - Aerodrome de Champagnole - Crotenay\", 46.7644444444, 5.82083333333), (\"LFGY - Aerodrome de Saint-Die - Remomeix\", 48.2672222222, 7.00861111111), (\"LFGZ - Aerodrome de Nuits Saint-Georges\", 47.1430555556, 4.96916666667), (\"LFHA - Aeroport d'Issoire - Le Broc\", 45.515, 3.2675), (\"LFHC - Aerodrome de Perouges - Meximieux\", 45.8697222222, 5.18722222222), (\"LFHD - Aeroport de Pierrelatte\", 44.3988888889, 4.71805555556), (\"LFHE - Aeroport de Romans - Saint-Paul\", 45.0661111111, 5.10333333333), (\"LFHF - Aerodrome de Ruoms\", 44.4452777778, 4.33388888889), (\"LFHG - Aerodrome de Saint-Chamond - L'Horme\", 45.4930555556, 4.53555555556), (\"LFHH - Aeroport de Vienne Reventin\", 45.4641666667, 4.82944444444), (\"LFHI - Aerodrome de Morestel\", 45.6877777778, 5.45361111111), (\"LFHJ - Aerodrome de Lyon - Corbas\", 45.6541666667, 4.91361111111), (\"LFHL - Aeroport de Langogne - Lesperon\", 44.7063888889, 3.88833333333), (\"LFHM - Aerodrome de Megeve\", 45.8208333333, 6.65222222222), (\"LFHN - Aerodrome de Bellegarde Vouvray\", 46.1241666667, 5.80611111111), (\"LFHO - Aeroport d'Aubenas Ardeche meridionale\", 44.5394444444, 4.37166666667), (\"LFHP - Aeroport du Puy - Loudes\", 45.0805555556, 3.76472222222), (\"LFHQ - Aeroport de Saint-Flour - Coltines\", 45.075, 2.9925), (\"LFHR - Aeroport de Brioude - Beaumont\", 45.325, 3.35916666667), (\"LFHS - Aerodrome de Bourg - Ceyzeriat\", 46.2055555556, 5.29166666667), (\"LFHT - Aeroport d'Ambert Le Poyet\", 45.5169444444, 3.74638888889), (\"LFHU - Altiport de l'Alpe d'Huez\", 45.0883333333, 6.08472222222), (\"LFHV - Aeroport de Villefranche - Tarare\", 45.92, 4.635), (\"LFHW - Aerodrome de Belleville - Villie-Morgon\", 46.1427777778, 4.71472222222), (\"LFHX - Aerodrome de Lapalisse - Perigny\", 46.2538888889, 3.58861111111), (\"LFHY - Aerodrome de Moulins - Montbeugny\", 46.5344444444, 3.42166666667), (\"LFHZ - Aerodrome de Sallanches Mont Blanc\", 45.9538888889, 6.63916666667), (\"LFIB - Aerodrome de Belves - Saint-Pardoux\", 44.7825, 0.958888888889), (\"LFID - Aeroport de Condom - Valence-sur-Baise\", 43.9102777778, 0.387222222222), (\"LFIF - Aerodrome de Saint-Affrique - Belmont\", 43.8241666667, 2.74861111111), (\"LFIG - Aerodrome de Cassagnes - Begonhes\", 44.1794444444, 2.51861111111), (\"LFIH - Aeroport de Chalais\", 45.2680555556, 0.0169444444444), (\"LFIK - Aerodrome de Riberac - Saint-Aulaye\", 45.2402777778, 0.266944444444), (\"LFIL - Aerodrome de Rion des Landes\", 43.9158333333, 0.949166666667), (\"LFIM - Aeroport de Saint-Gaudens - Montrejeau\", 43.1086111111, 0.620277777778), (\"LFIP - Aerodrome de Peyresourde - Balestas\", 42.7969444444, 0.435555555556), (\"LFIR - Aerodrome de Revel - Montgey\", 43.4813888889, 1.98), (\"LFIT - Aerodrome de Toulouse - Bourg Saint-Bernard\", 43.6122222222, 1.72527777778), (\"LFIV - Aerodrome de Vendays - Montalivet\", 45.3805555556, 1.11583333333), (\"LFIX - Aerodrome d'Itxassou\", 43.3375, 1.42222222222), (\"LFIY - Aerodrome de Saint-Jean d'Angely - Saint-Denis du Pin\", 45.9663888889, 0.525277777778), (\"LFJA - Aerodrome de Chaumont - Semoutiers\", 48.0916666667, 5.05), (\"LFJB - Aeroport de Mauleon\", 46.9038888889, 0.696388888889), (\"LFJC - Aeroport de Clamecy\", 47.4383333333, 3.50861111111), (\"LFJD - Aerodrome de Corlier\", 46.0397222222, 5.49694444444), (\"LFJE - Aerodrome de La Motte Chalancon\", 44.4997222222, 5.40333333333), (\"LFJF - Aerodrome d'Aubenasson\", 44.6963888889, 5.15472222222), (\"LFJH - Aerodrome de Cazeres - Palaminy\", 43.2022222222, 1.05111111111), (\"LFJI - Aerodrome de Marennes\", 45.8238888889, 1.07722222222), (\"LFJL - Aeroport Metz Nancy Lorraine\", 48.9783333333, 6.24666666667), (\"LFJR - Angers Loire Aeroport\", 47.5602777778, 0.312222222222), (\"LFJS - Aeroport de Soissons - Courmelles\", 49.3458333333, 3.28416666667), (\"LFJT - Aerodrome de Tours - Le Louroux\", 47.15, 0.712777777778), (\"LFJU - Aerodrome de Lurcy - Levis\", 46.7127777778, 2.94611111111), (\"LFJY - Chambley-Bussieres Air Base\", 49.0255555556, 5.87611111111), (\"LFKA - Aerodrome d'Albertville\", 45.6272222222, 6.32972222222), (\"LFKB - Aeroport de Bastia Poretta\", 42.55, 9.48472222222), (\"LFKC - Aeroport de Calvi Sainte-Catherine\", 42.5202777778, 8.79305555556), (\"LFKD - Aerodrome de Sollieres - Sardieres\", 45.2563888889, 6.80138888889), (\"LFKE - Aerodrome de Saint-Jean en Royans\", 45.0277777778, 5.31), (\"LFKF - Aeroport de Figari Sud Corse\", 41.5022222222, 9.09666666667), (\"LFKG - Aerodrome de Ghisonaccia Alzitone\", 42.055, 9.40194444444), (\"LFKH - Aerodrome de Saint-Jean d'Avelanne\", 45.5166666667, 5.68055555556), (\"LFKJ - Aeroport d'Ajaccio Napoleon Bonaparte\", 41.9238888889, 8.8025), (\"LFKL - Aerodrome de Lyon - Brindas\", 45.7116666667, 4.69777777778), (\"LFKM - Aerodrome de Saint-Galmier\", 45.6072222222, 4.30583333333), (\"LFKO - Aerodrome de Propriano\", 41.6613888889, 8.895), (\"LFKP - Aerodrome de La Tour-du-Pin - Cessieu\", 45.5572222222, 5.38472222222), (\"LFKR - Aerodrome de Saint-Remy de Maurienne\", 0.0, 0.0), (\"LFKS - Base aerienne 126 de Solenzara\", 41.9261111111, 9.40527777778), (\"LFKT - Aerodrome de Corte\", 42.2908333333, 9.19388888889), (\"LFKX - Aerodrome de Meribel\", 45.4069444444, 6.58055555556), (\"LFKY - Aerodrome de Belley - Peyrieu\", 45.695, 5.69277777778), (\"LFLA - Aeroport d'Auxerre - Branches\", 47.8463888889, 3.49666666667), (\"LFLB - Aeroport de Chambery - Savoie\", 45.6391666667, 5.88), (\"LFLC - Aeroport de Clermont-Ferrand Auvergne\", 45.7858333333, 3.1625), (\"LFLD - Aeroport de Bourges\", 47.0644444444, 2.37888888889), (\"LFLE - Aeroport de Chambery - Challes-les-Eaux\", 45.5613888889, 5.97694444444), (\"LFLG - Aerodrome de Grenoble - Le Versoud\", 45.2191666667, 5.84972222222), (\"LFLH - Aeroport de Chalon - Champforgeuil\", 46.8283333333, 4.81694444444), (\"LFLI - Aerodrome d'Annemasse\", 46.1919444444, 6.26944444444), (\"LFLJ - Aerodrome de Courchevel\", 45.3966666667, 6.63361111111), (\"LFLK - Aerodrome d'Oyonnax - Arbent\", 46.2791666667, 5.6675), (\"LFLL - Aeroport Lyon Saint-Exupery\", 45.7255555556, 5.08111111111), (\"LFLM - Aeroport de Macon - Charnay\", 46.2958333333, 4.79583333333), (\"LFLN - Aeroport de Saint-Yan\", 46.4063888889, 4.02111111111), (\"LFLO - Aeroport de Roanne - Renaison\", 46.0527777778, 3.99972222222), (\"LFLP - Aeroport d'Annecy Haute-Savoie Mont Blanc\", 45.9308333333, 6.10638888889), (\"LFLQ - Aeroport de Montelimar - Ancone\", 44.5836111111, 4.74055555556), (\"LFLR - Aeroport de Saint-Rambert d'Albon\", 45.2561111111, 4.82583333333), (\"LFLS - Aeroport International de Grenoble Isere\", 45.3630555556, 5.33277777778), (\"LFLT - Aerodrome de Montlucon - Domerat\", 46.3536111111, 2.57222222222), (\"LFLU - Aeroport de Valence - Chabeuil\", 44.9155555556, 4.96861111111), (\"LFLV - Aeroport de Vichy - Charmeil\", 46.1716666667, 3.40416666667), (\"LFLW - Aeroport d'Aurillac\", 44.8975, 2.41666666667), (\"LFLX - Aeroport de Chateauroux - Deols\", 46.8602777778, 1.72111111111), (\"LFLY - Aeroport de Lyon Bron\", 45.7294444444, 4.93888888889), (\"LFLZ - Aerodrome de Feurs - Chambeon\", 45.7036111111, 4.20111111111), (\"LFMA - Aeroport d'Aix Les Milles\", 43.5016666667, 5.37083333333), (\"LFMC - Aeroport du Luc - Le Cannet\", 43.3847222222, 6.38694444444), (\"LFMD - Aeroport de Cannes - Mandelieu\", 43.5475, 6.95527777778), (\"LFME - Aeroport de NImes Courbessac\", 43.8538888889, 4.41361111111), (\"LFMF - Aerodrome de Fayence\", 43.6061111111, 6.70277777778), (\"LFMG - Aerodrome de Montagne Noire\", 43.4075, 1.99027777778), (\"LFMH - Aeroport de Saint-etienne - Boutheon\", 45.5341666667, 4.29722222222), (\"LFMI - Base aerienne 125 d'Istres - Le Tube\", 43.5225, 4.92416666667), (\"LFMK - Aeroport de Carcassonne Salvaza\", 43.2158333333, 2.30861111111), (\"LFML - Aeroport de Marseille Provence\", 43.4366666667, 5.215), (\"LFMN - Aeroport Nice Cote d'Azur\", 43.6652777778, 7.215), (\"LFMO - Base aerienne 115 d'Orange Caritat\", 44.14, 4.86527777778), (\"LFMP - Aeroport de Perpignan - Rivesaltes\", 42.7408333333, 2.86972222222), (\"LFMQ - Aeroport du Castellet\", 43.2533333333, 5.78722222222), (\"LFMR - Aeroport de Barcelonnette - Saint-Pons\", 44.3883333333, 6.61027777778), (\"LFMS - Aerodrome d'Ales Cevennes\", 44.0736111111, 4.14388888889), (\"LFMT - Aeroport Montpellier Mediterranee\", 43.5833333333, 3.96138888889), (\"LFMU - Aeroport de Beziers - Cap d'Agde en Languedoc\", 43.3233333333, 3.35333333333), (\"LFMV - Aeroport d'Avignon - Caumont\", 43.9066666667, 4.90194444444), (\"LFMW - Aeroport de Castelnaudary - Villeneuve\", 43.3122222222, 1.92111111111), (\"LFMX - Aeroport de Chateau Arnoux Saint-Auban\", 44.06, 5.99138888889), (\"LFMY - Base aerienne 701 de Salon de Provence\", 43.6027777778, 5.10805555556), (\"LFMZ - Aerodrome de Lezignan Corbieres\", 43.1758333333, 2.73361111111), (\"LFNA - Aerodrome de Gap - Tallard\", 44.455, 6.03777777778), (\"LFNB - Aerodrome de Mende - Brenoux\", 44.5041666667, 3.5275), (\"LFNC - Aeroport de Mont-Dauphin - Saint-Crepin\", 44.7016666667, 6.60027777778), (\"LFND - Aeroport de Pont - Saint - Esprit\", 0.0, 0.0), (\"LFNE - Aerodrome de Salon - Eyguieres\", 43.6583333333, 5.01361111111), (\"LFNF - Aeroport de Vinon\", 43.7377777778, 5.78416666667), (\"LFNG - Aeroport de Montpellier - Candillargues\", 43.6102777778, 4.07027777778), (\"LFNH - Aerodrome de Carpentras\", 44.0233333333, 5.09083333333), (\"LFNJ - Aerodrome d'Aspres sur Buech\", 44.5188888889, 5.7375), (\"LFNL - Aerodrome de Saint-Martin de Londres\", 43.8008333333, 3.7825), (\"LFNN - Aerodrome de Narbonne\", 43.1941666667, 3.05166666667), (\"LFNO - Aerodrome de Florac - Sainte-Enimie\", 44.2863888889, 3.46666666667), (\"LFNP - Aerodrome de Pezenas - Nizas\", 43.5058333333, 3.41361111111), (\"LFNQ - Aerodrome de Mont-Louis La Quillane\", 42.5436111111, 2.12), (\"LFNR - Aerodrome de Berre - La Fare\", 43.5377777778, 5.17833333333), (\"LFNS - Aerodrome de Sisteron Theze\", 44.2875, 5.93027777778), (\"LFNT - Aerodrome d'Avignon - Pujaut\", 43.9969444444, 4.75555555556), (\"LFNU - Aerodrome d'Uzes\", 44.0847222222, 4.39527777778), (\"LFNV - Aerodrome de Valreas - Visan\", 44.3369444444, 4.90805555556), (\"LFNW - Aerodrome de Puivert\", 42.9113888889, 2.05611111111), (\"LFNX - Aerodrome de Bedarieux - La Tour-sur-Orb\", 43.6408333333, 3.14555555556), (\"LFNZ - Aerodrome du Mazet de Romanin\", 43.7688888889, 4.89361111111), (\"LFOA - Base aerienne 702 d'Avord\", 47.0566666667, 2.63861111111), (\"LFOB - Aeroport de Beauvais Tille\", 49.4544444444, 2.11277777778), (\"LFOC - Aeroport de Chateaudun\", 48.0577777778, 1.37944444444), (\"LFOD - Aerodrome de Saumur Saint-Florent\", 47.2566666667, 0.113611111111), (\"LFOE - Base aerienne 105 d'evreux - Fauville\", 49.0286111111, 1.22), (\"LFOF - Aeroport d'Alencon - Valframbert\", 48.4475, 0.109166666667), (\"LFOG - Aeroport de Flers - Saint-Paul\", 48.7525, 0.589444444444), (\"LFOH - Aeroport du Havre - Octeville\", 49.5338888889, 0.0880555555556), (\"LFOI - Aeroport d'Abbeville\", 50.1430555556, 1.8325), (\"LFOJ - Base aerienne 123 d'Orleans - Bricy\", 47.9877777778, 1.76055555556), (\"LFOK - Aeroport de Paris Vatry\", 48.7733333333, 4.20611111111), (\"LFOL - Aeroport de L'Aigle - Saint-Michel\", 48.7597222222, 0.659166666667), (\"LFOM - Aeroport de Lessay\", 49.2030555556, 1.50666666667), (\"LFON - Aerodrome de Dreux Vernouillet\", 48.7066666667, 1.36277777778), (\"LFOO - Aeroport Les sables - Talmont\", 46.4769444444, 1.72277777778), (\"LFOP - Aeroport Rouen Vallee de Seine\", 49.3908333333, 1.18388888889), (\"LFOQ - Aeroport de Blois - Le Breuil\", 47.6797222222, 1.20583333333), (\"LFOR - Aeroport de Chartres - Champhol\", 48.4588888889, 1.52388888889), (\"LFOS - Aeroport de Saint-Valery - Vittefleur\", 49.8361111111, 0.655), (\"LFOT - Aeroport de Tours Val de Loire\", 47.4319444444, 0.723055555556), (\"LFOU - Aerodrome de Cholet Le Pontreau\", 47.0819444444, 0.877222222222), (\"LFOV - Aeroport de Laval - Entrammes\", 48.0322222222, 0.742777777778), (\"LFOW - Aerodrome de Saint-Quentin - Roupy\", 49.8169444444, 3.20666666667), (\"LFOX - Aeroport d'etampes Mondesir\", 48.3819444444, 2.07527777778), (\"LFOY - Aeroport du Havre - Saint-Romain\", 49.5438888889, 0.359722222222), (\"LFOZ - Aeroport d'Orleans - Saint-Denis de l'Hotel\", 47.8975, 2.16416666667), (\"LFPA - Aeroport de Persan - Beaumont\", 49.1658333333, 2.31305555556), (\"LFPB - Aeroport Paris - Le Bourget\", 48.9694444444, 2.44138888889), (\"LFPC - Base aerienne 110 de Creil\", 49.2508333333, 2.52166666667), (\"LFPD - Aeroport de Bernay - Saint-Martin\", 49.1027777778, 0.566666666667), (\"LFPE - Aeroport de Meaux - Esbly\", 48.9277777778, 2.83527777778), (\"LFPF - Aerodrome de Beynes - Thiverval\", 48.8436111111, 1.90888888889), (\"LFPG - Aeroport de Paris Charles de Gaulle\", 49.0097222222, 2.54777777778), (\"LFPH - Aeroport de Chelles le Pin\", 48.8977777778, 2.6075), (\"LFPI - Heliport de Paris - Issy-les-Moulineaux\", 48.8333333333, 2.27277777778), (\"LFPK - Aeroport de Coulommiers - Voisins\", 48.8377777778, 3.01527777778), (\"LFPL - Aeroport de Lognes - emerainville\", 48.8230555556, 2.62388888889), (\"LFPM - Base aerienne de Melun - Villaroche\", 48.6052777778, 2.67083333333), (\"LFPN - Aeroport de Toussus le Noble\", 48.7497222222, 2.11111111111), (\"LFPO - Aeroport Paris - Orly\", 48.7233333333, 2.37944444444), (\"LFPP - Aeroport du Plessis - Belleville\", 49.11, 2.73805555556), (\"LFPQ - Aeroport de Fontenay - Tresigny\", 48.7072222222, 2.90444444444), (\"LFPT - Aeroport de Pontoise - Cormeilles-en-Vexin\", 49.0966666667, 2.04083333333), (\"LFPU - Aerodrome de Moret - episy\", 48.3419444444, 2.79944444444), (\"LFPV - Base aerienne 107 de Velizy Villacoublay\", 48.7741666667, 2.19166666667), (\"LFPX - Aerodrome de Chavenay - Villepreux\", 48.8436111111, 1.98222222222), (\"LFPY - Base aerienne 217 de Bretigny sur Orge\", 48.5961111111, 2.33222222222), (\"LFPZ - Aerodrome de Saint-Cyr l'ecole\", 48.8113888889, 2.07472222222), (\"LFQA - Aeroport de Reims - Prunay\", 49.2086111111, 4.15666666667), (\"LFQB - Aeroport de Troyes - Barberey\", 48.3216666667, 4.01666666667), (\"LFQC - Aeroport de Luneville - Croismare\", 48.5947222222, 6.54333333333), (\"LFQD - Aeroport d'Arras - Roclincourt\", 50.3247222222, 2.80416666667), (\"LFQE - Base aerienne d'etain - Rouvres\", 49.2291666667, 5.68027777778), (\"LFQF - Aeroport d'Autun Bellevue\", 46.9725, 4.26222222222), (\"LFQG - Aeroport de Nevers - Fourchambault\", 47.0036111111, 3.11083333333), (\"LFQH - Aeroport de Chatillon Sur Seine\", 47.8463888889, 4.58055555556), (\"LFQI - Base aerienne 103 de Cambrai - epinoy\", 50.2188888889, 3.15194444444), (\"LFQJ - Aeroport de Maubeuge - elesmes\", 50.3091666667, 4.03138888889), (\"LFQK - Aeroport de Chalons - ecury-sur-Coole\", 48.9061111111, 4.35416666667), (\"LFQL - Aeroport de Lens - Benifontaine\", 50.4672222222, 2.82194444444), (\"LFQM - Aeroport de Besancon - La Veze\", 47.2052777778, 6.08055555556), (\"LFQN - Aeroport de Saint-Omer - Wizernes\", 50.7294444444, 2.23583333333), (\"LFQO - Aeroport de Lille - Marcq-en-Baroeul\", 50.6880555556, 3.07666666667), (\"LFQP - Base aerienne de Phalsbourg - Bourscheid\", 48.7727777778, 7.215), (\"LFQQ - Aeroport de Lille - Lesquin\", 50.5633333333, 3.08694444444), (\"LFQR - Aeroport de Romilly sur Seine\", 0.0, 0.0), (\"LFQS - Aeroport de Vitry en Artois\", 50.3383333333, 2.99333333333), (\"LFQT - Aeroport de Merville - Calonne\", 50.6166666667, 2.64), (\"LFQU - Aerodrome de Sarre Union\", 48.9513888889, 7.07777777778), (\"LFQV - Aeroport de Charleville-Mezieres - Belval\", 49.7858333333, 4.64416666667), (\"LFQW - Aeroport de Vesoul - Frotey\", 47.6394444444, 6.20527777778), (\"LFQX - Aerodrome de Juvancourt\", 48.115, 4.82083333333), (\"LFQY - Aerodrome de Saverne - Steinbourg\", 48.7541666667, 7.42638888889), (\"LFQZ - Aerodrome de Dieuze - Gueblange\", 48.7752777778, 6.71527777778), (\"LFRA - Aerodrome d'Angers - Avrille\", 0.0, 0.0), (\"LFRB - Aeroport de Brest Bretagne\", 48.4472222222, 4.42166666667), (\"LFRC - Aeroport de Cherbourg - Maupertus\", 49.6508333333, 1.47527777778), (\"LFRD - Aeroport de Dinard Pleurtuit Saint-Malo\", 48.5877777778, 2.08), (\"LFRE - Aeroport de La Baule Escoublac\", 47.2894444444, 2.34638888889), (\"LFRF - Aeroport de Granville Mont Saint-Michel\", 48.8827777778, 1.56388888889), (\"LFRG - Aeroport de Deauville - Saint-Gatien\", 49.3633333333, 0.16), (\"LFRH - Aeroport de Lorient Bretagne Sud\", 47.7605555556, 3.44), (\"LFRI - Aeroport de La Roche-sur-Yon - Les Ajoncs\", 46.7025, 1.38166666667), (\"LFRJ - Base d'aeronautique navale de Landivisiau\", 48.53, 4.15166666667), (\"LFRK - Aeroport de Caen - Carpiquet\", 49.1733333333, 0.45), (\"LFRL - Base d'aeronautique navale de Lanveoc - Poulmic\", 48.2816666667, 4.44583333333), (\"LFRM - Aeroport du Mans - Arnage\", 47.9486111111, 0.201666666667), (\"LFRN - Aeroport de Rennes - Saint-Jacques\", 48.0719444444, 1.73222222222), (\"LFRO - Aeroport de Lannion\", 48.755, 3.47444444444), (\"LFRP - Aeroport de Ploermel - Loyat\", 48.0027777778, 2.37722222222), (\"LFRQ - Aeroport de Quimper Cornouaille\", 47.975, 4.16777777778), (\"LFRS - Aeroport Nantes Atlantique\", 47.1569444444, 1.60777777778), (\"LFRT - Aeroport de Saint-Brieuc Armor\", 48.5375, 2.85666666667), (\"LFRU - Aeroport de Morlaix Ploujean\", 48.6008333333, 3.81666666667), (\"LFRV - Aeroport de Vannes - Meucon\", 47.7191666667, 2.72333333333), (\"LFRW - Aerodrome d'Avranches - Le Val Saint-Pere\", 48.6616666667, 1.40444444444), (\"LFRZ - Aeroport de Saint-Nazaire - Montoir\", 47.3105555556, 2.15666666667), (\"LFSA - Aeroport de Besancon - Thise\", 47.2747222222, 6.08416666667), (\"LFSB - Aeroport international Basel Mulhouse Freiburg\", 47.59, 7.52916666667), (\"LFSD - Aeroport de Dijon Bourgogne - Longvic\", 47.2658333333, 5.095), (\"LFSE - Aerodrome Epinal - Dogneville\", 48.2119444444, 6.44916666667), (\"LFSF - Base aerienne 128 de Metz Frescaty\", 49.0763888889, 6.13388888889), (\"LFSG - Aeroport d'epinal - Mirecourt\", 48.325, 6.06666666667), (\"LFSH - Aerodrome d'Haguenau\", 48.7977777778, 7.82027777778), (\"LFSI - Base aerienne 113 de Saint-Dizier - Robinson\", 48.6333333333, 4.90805555556), (\"LFSJ - Aeroport de Sedan - Douzy\", 49.6597222222, 5.03777777778), (\"LFSK - Aeroport de Vitry-le-Francois - Vauclerc\", 48.7033333333, 4.68444444444), (\"LFSL - Aeroport de Brive Vallee de la Dordogne\", 45.0397222222, 1.48555555556), (\"LFSM - Aeroport de Montbeliard - Courcelles\", 47.4866666667, 6.79138888889), (\"LFSN - Aeroport de Nancy - Essey\", 48.6922222222, 6.22611111111), (\"LFSO - Base aerienne 133 de Nancy - Ochey\", 48.5833333333, 5.955), (\"LFSP - Aerodrome de Pontarlier\", 46.9094444444, 6.33), (\"LFSR - Aeroport de Reims Champagne\", 0.0, 0.0), (\"LFST - Aeroport de Strasbourg Entzheim\", 48.5405555556, 7.63277777778), (\"LFSU - Aeroport de Langres - Rolampont\", 47.9655555556, 5.295), (\"LFSV - Aerodrome de Pont Saint-Vincent\", 48.6, 6.04972222222), (\"LFSW - Aeroport d'epernay - Plivot\", 49.0052777778, 4.08694444444), (\"LFSX - Base aerienne 116 de Luxeuil - Saint-Sauveur\", 47.7861111111, 6.36444444444), (\"LFSZ - Aeroport de Vittel Champ de courses\", 0.0, 0.0), (\"LFTF - Aeroport de Cuers - Pierrefeu\", 43.2475, 6.12722222222), (\"LFTH - Aeroport de Toulon - Hyeres - Le Palyvestre\", 43.0972222222, 6.14611111111), (\"LFTL - Heliport de Cannes - Quai du large\", 0.0, 0.0), (\"LFTM - Aerodrome de Serres - La Batie-Montsaleon\", 44.4583333333, 5.72833333333), (\"LFTN - Aerodrome de La Grand'Combe\", 44.2444444444, 4.01222222222), (\"LFTP - Aerodrome de Puimoisson\", 43.8688888889, 6.16277777778), (\"LFTQ - Aerodrome de Chateaubriant - Pouance\", 47.7405555556, 1.18805555556), (\"LFTW - Aeroport de NImes - Garons\", 43.7575, 4.41638888889), (\"LFTZ - Aeroport de La Mole - Saint-Tropez\", 43.2063888889, 6.4825), (\"LFXA - Aerodrome d'Amberieu\", 45.9797222222, 5.33777777778), (\"LFXB - Aeroport de Saintes - Thenac\", 45.7019444444, 0.636111111111), (\"LFXI - Base aerienne 200 Apt - Saint-Christol\", 0.0, 0.0), (\"LFXM - Aerodrome de Mourmelon\", 0.0, 0.0), (\"LFXU - Aeroport des Mureaux\", 48.9983333333, 1.94277777778), (\"LFYD - Aeroport de Damblain\", 48.0833333333, 5.66666666667), (\"LFYG - Aerodrome de Cambrai - Niergnies\", 50.1425, 3.265), (\"LFYH - Aeroport de Broyes les Pesmes\", 0.0, 0.0), (\"LFYM - Aeroport de Marigny Le Grand\", 0.0, 0.0), (\"LFYR - Aeroport de Romorantin - Pruniers\", 47.3208333333, 1.68888888889), (\"LFYS - Aerodrome de Sainte-Leocadie\", 42.4466666667, 2.01027777778), (\"LFYT - Base aerienne de Saint-Simon - Clastres\", 0.0, 0.0)";
        
        sqlite3_prepare_v2(_flightDB, insert_stmt, -1, &statement, NULL);
        
        if (sqlite3_step(statement) == SQLITE_DONE)
            NSLog(@"Flights added");
        else
            NSLog(@"Failed to add flights");
        
        sqlite3_finalize(statement);
        sqlite3_close(_flightDB);
    }
}

#pragma mark - Find the nearest location
- (void)findNearestLoc:(CLLocation *)loc
{
    const char *dbpath = [_databasePath UTF8String];
    sqlite3_stmt *statement;
    double distance = 999999999;
    NSString *icao;
    
    if (sqlite3_open(dbpath, &_flightDB) == SQLITE_OK)
    {
        const char *query_stmt = "SELECT name, lat, long FROM flights";
        
        if (sqlite3_prepare_v2(_flightDB, query_stmt, -1, &statement, NULL) == SQLITE_OK)
        {
            while (sqlite3_step(statement) == SQLITE_ROW)
            {
                double latitude = sqlite3_column_double(statement, 1);
                double longitude = sqlite3_column_double(statement, 2);
                CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
                
                CLLocationDistance d = [loc distanceFromLocation:location];
                
                if(d < distance)
                {
                    distance = d;
                    
                    icao = [NSString stringWithFormat:@"%s", sqlite3_column_text(statement, 0)];
                    icao = [icao substringToIndex:4];
                }
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(_flightDB);
    }
    
    _icaoCode = icao;
    [self setStartDate:_icaoCode withTime:[NSDate date]];
}

#pragma mark - Get current location
-(void)CurrentLocationIdentifier
{
    _locationManager = [CLLocationManager new];
    _locationManager.delegate = self;
    _locationManager.distanceFilter = kCLDistanceFilterNone;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [_locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    _userLocation = [locations objectAtIndex:0];
    [_locationManager stopUpdatingLocation];
    [self findNearestLoc:_userLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No location services" message:@"We must be able to locate you to use this app." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    
    self.startLabel.text = @"";
    self.endLabel.text = @"";
    self.durationLabel.text = @"";
    [self.actionButton setTitle:START forState:UIControlStateNormal];
}

#pragma mark - Save the flight in the databse
- (void) saveData
{
    sqlite3_stmt *statement;
    const char *dbpath = [_databasePath UTF8String];
    
    if (sqlite3_open(dbpath, &_flightDB) == SQLITE_OK)
    {
        NSDate *date = [NSDate date];
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"MM/dd/yyyy"];
        NSString *dateString = [dateFormat stringFromDate:date];
        
        NSString *start = [self.df stringFromDate:_startDate];
        NSString *end = [self.df stringFromDate:_endDate];
        
        NSString *insertSQL = [NSString stringWithFormat:@"INSERT INTO FLIGHTS_DONE (date, icao, dep_hour, ari_hour, duration) VALUES (\"%@\", \"%@\", \"%@\", \"%@\", \"%@\")", dateString, _icaoCode, start, end, _duration];
        
        const char *insert_stmt = [insertSQL UTF8String];

        sqlite3_prepare_v2(_flightDB, insert_stmt, -1, &statement, NULL);
        if (sqlite3_step(statement) == SQLITE_DONE)
            NSLog(@"Flight added");
        else
            NSLog(@"Failed to add flight");

        sqlite3_finalize(statement);
        sqlite3_close(_flightDB);
    }
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval
{
    NSInteger ti = (NSInteger)interval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
}

@end
