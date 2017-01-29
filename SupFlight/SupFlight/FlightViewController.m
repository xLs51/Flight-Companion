//
//  FlightViewController.m
//  SupFlight
//
//  Created by Local Administrator on 08/06/14.
//  Copyright (c) 2014 Jordan. All rights reserved.
//

#import "FlightViewController.h"
#import "FlightCell.h"

#import <sqlite3.h>

@interface FlightViewController ()

@property (strong, nonatomic) NSMutableArray *dates;
@property (strong, nonatomic) NSMutableArray *icaos;
@property (strong, nonatomic) NSMutableArray *deps;
@property (strong, nonatomic) NSMutableArray *aris;
@property (strong, nonatomic) NSMutableArray *durations;
@property (strong, nonatomic) NSMutableArray *ids;

@property (strong, nonatomic) UITableView *myTableView;

@property (strong, nonatomic) NSString *databasePath;
@property (nonatomic) sqlite3 *flightDB;

- (void)findSavedFlight;
- (IBAction)deleteAll:(id)sender;

@end

@implementation FlightViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _dates = [[NSMutableArray alloc] init];
    _icaos = [[NSMutableArray alloc] init];
    _deps = [[NSMutableArray alloc] init];
    _aris = [[NSMutableArray alloc] init];
    _durations = [[NSMutableArray alloc] init];
    _ids = [[NSMutableArray alloc] init];
    
    [self findSavedFlight];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.dates count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FlightCell * cell = [tableView dequeueReusableCellWithIdentifier:@"myCell"];
    
    if (!cell)
    {
        [tableView registerNib:[UINib nibWithNibName:@"FlightCell" bundle:nil] forCellReuseIdentifier:@"myCell"];
        cell = [tableView dequeueReusableCellWithIdentifier:@"myCell"];
    }
    
    self.myTableView = tableView;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(FlightCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *myLabel = @"Date: ";
    myLabel = [myLabel stringByAppendingString:[self.dates objectAtIndex:indexPath.row]];
    cell.dateLabel.text = myLabel;
    
    NSString *myDep = @"Departure: ";
    myDep = [myDep stringByAppendingString:[self.icaos objectAtIndex:indexPath.row]];
    myDep = [myDep stringByAppendingString:@" - "];
    myDep = [myDep stringByAppendingString:[self.deps objectAtIndex:indexPath.row]];
    cell.departureLabel.text = myDep;
    
    NSString *myAri = @"Arrival: ";
    myAri = [myAri stringByAppendingString:[self.icaos objectAtIndex:indexPath.row]];
    myAri = [myAri stringByAppendingString:@" - "];
    myAri = [myAri stringByAppendingString:[self.aris objectAtIndex:indexPath.row]];
    cell.arrivalLabel.text = myAri;
    
    NSString *myDur = @"Duration: ";
    myDur = [myDur stringByAppendingString:[self.durations objectAtIndex:indexPath.row]];
    cell.durationLabel.text = myDur;
    
    cell.idLabel.text = [self.ids objectAtIndex:indexPath.row];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 110;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        const char *dbpath = [_databasePath UTF8String];
        sqlite3_stmt *statement;
        
        if(sqlite3_open(dbpath, &_flightDB) == SQLITE_OK)
        {
            NSString *insertSQL = [NSString stringWithFormat:@"DELETE FROM flights_done WHERE id = \"%@\"", [self.ids objectAtIndex:indexPath.row]];
            
            const char *sql = [insertSQL UTF8String];
            
            if(sqlite3_prepare_v2(_flightDB, sql,-1, &statement, NULL) == SQLITE_OK)
            {
                if(sqlite3_step(statement) == SQLITE_DONE)
                {
                    [self.ids removeObjectAtIndex:[indexPath row]];
                    [self.dates removeObjectAtIndex:[indexPath row]];
                    [self.icaos removeObjectAtIndex:[indexPath row]];
                    [self.deps removeObjectAtIndex:[indexPath row]];
                    [self.aris removeObjectAtIndex:[indexPath row]];
                    [self.durations removeObjectAtIndex:[indexPath row]];
                    [self.myTableView reloadData];
                    NSLog(@"Flight deleted");
                }
                else
                    NSLog(@"Failed to delete the flight");
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(_flightDB);
    }
}

#pragma mark - Get all the saved flight
- (void)findSavedFlight
{
    NSString *docsDir;
    NSArray *dirPaths;
    
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    docsDir = dirPaths[0];
    
    _databasePath = [[NSString alloc] initWithString: [docsDir stringByAppendingPathComponent:@"flight.sqlite"]];
    
    const char *dbpath = [_databasePath UTF8String];
    sqlite3_stmt *statement;
    
    if (sqlite3_open(dbpath, &_flightDB) == SQLITE_OK)
    {
        const char *query_stmt = "SELECT id, date, icao, dep_hour, ari_hour, duration FROM flights_done";
        
        if (sqlite3_prepare_v2(_flightDB, query_stmt, -1, &statement, NULL) == SQLITE_OK)
        {
            while (sqlite3_step(statement) == SQLITE_ROW)
            {
                [_ids addObject:[NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 0)]];
                [_dates addObject:[NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 1)]];
                [_icaos addObject:[NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 2)]];
                [_deps addObject:[NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 3)]];
                [_aris addObject:[NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 4)]];
                [_durations addObject:[NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 5)]];
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(_flightDB);
    }
}

- (IBAction)deleteAll:(id)sender
{
    //UPDATE TABLEVIEW
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Delete", nil) message:NSLocalizedString(@"Are you sure you want to delete all the flights ?", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil) otherButtonTitles:NSLocalizedString(@"Delete", nil), nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex)
    {
        case 0:
        {
            NSLog(@"Delete cancel");
        }
        break;
            
        case 1:
        {
            const char *dbpath = [_databasePath UTF8String];
            sqlite3_stmt *statement;
            
            if(sqlite3_open(dbpath, &_flightDB) == SQLITE_OK)
            {
                const char *sql = "DELETE FROM flights_done";
                
                if(sqlite3_prepare_v2(_flightDB, sql,-1, &statement, NULL) == SQLITE_OK)
                {
                    if(sqlite3_step(statement) == SQLITE_DONE)
                    {
                        [self.ids removeAllObjects];
                        [self.dates removeAllObjects];
                        [self.icaos removeAllObjects];
                        [self.deps removeAllObjects];
                        [self.aris removeAllObjects];
                        [self.durations removeAllObjects];
                        [self.myTableView reloadData];
                        NSLog(@"Flights deleted");
                    }
                    else
                        NSLog(@"Failed to delete flights");
                }
                sqlite3_finalize(statement);
            }
            sqlite3_close(_flightDB);
        }
        break;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
