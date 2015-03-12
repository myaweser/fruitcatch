//
//  MultiplayerGameViewController.m
//  Fruit Catch
//
//  Created by Caio de Souza on 13/01/15.
//  Copyright (c) 2015 Caio de Souza. All rights reserved.
//

#import "MultiplayerGameViewController.h"
#import "MyScene.h"
#import "JIMCLevel.h"
#import "JIMCSwapFruitSingleton.h"
#import "JIMCPowerUp.h"
#import "SettingsSingleton.h"
#import "Life.h"
#import "NetworkController.h"
#import <Nextpeer/Nextpeer.h>
#import <Nextpeer/NPTournamentDelegate.h>
#import "NextpeerHelper.h"

#define playerIdKey @"PlayerId"
#define randomNumberKey @"randomNumber"

#define START_GAME_SYNC_EVENT_NAME @"com.sucodefrutasteam.fruitcatch.syncevent.startgame"
#define TIMEOUT 5.0

@interface MultiplayerGameViewController () <NPTournamentDelegate>

// The level contains the tiles, the fruits, and most of the gameplay logic.
@property (nonatomic) JIMCLevel *level;


// The scene draws the tiles and fruit sprites, and handles swipes.
@property (nonatomic) MyScene *scene;



@property (assign, nonatomic) NSUInteger movesLeft;


@property (weak, nonatomic) IBOutlet UILabel *targetLabel;
@property (weak, nonatomic) IBOutlet UILabel *movesLabel;
@property (weak, nonatomic) IBOutlet UILabel *scoreLabel;
@property (weak, nonatomic) IBOutlet UIButton *shuffleButton;
@property (weak, nonatomic) IBOutlet UIImageView *gameOverPanel;
@property(nonatomic) BOOL isPlayer1;
@property (retain) Match *match;

@property (nonatomic) UITapGestureRecognizer *tapGestureRecognizer;

@property (nonatomic) AVAudioPlayer *backgroundMusic;

@property (nonatomic) NSSet *possibleMoves;

@property(nonatomic) int randomNumber;

@property(nonatomic) NSMutableArray *orderOfPlayers;

@property(nonatomic) __block NSMutableArray *arrayOfColumnArray;

@property(nonatomic) BOOL isMyMove;

@property(nonatomic) int fruitCounter;

@property(nonatomic) BOOL isFirstRound;

@property(nonatomic) BOOL isExecutingOpponentMove;

@property(nonatomic) NSMutableArray *auxiliaryArray;

@property(nonatomic) dispatch_semaphore_t semaphore;

@property(nonatomic) int fruitCounter2;

@property(nonatomic) NSMutableArray *parameter;


@end

@implementation MultiplayerGameViewController
//MEtodos somente para tirar o warning
-(void)setNotInMatch{}
-(void)matchStarted:(Match *)match{}
-(void)player:(unsigned char)playerIndex movedToPosX:(int)posX{}
-(void)gameOver:(unsigned char)winnerIndex{}


- (void)viewDidLoad {
    
    [super viewDidLoad];
    _parameter = [[NSMutableArray alloc]init];
    _isMyMove = NO;
    _isFirstRound = YES;
    _arrayOfColumnArray = [NSMutableArray array];
    _fruitCounter2 = 0;
    [self registerNotifications];
    //[self.networkEngine setDelegate:self];
    // Configure the view.
    SKView *skView = [[SKView alloc]initWithFrame:[UIScreen mainScreen].bounds];
    self.view = skView;
    //_multipleTouchEnabled = NO;
    
    // Create and configure the scene.
    self.scene = [MyScene sceneWithSize:skView.bounds.size];
    self.scene.scaleMode = SKSceneScaleModeAspectFill;
    
    //self.scene.viewController = self;
    self.levelString = @"Level_0";
    // Load the level.
    self.level = [[JIMCLevel alloc] initWithFile:self.levelString];
    self.scene.level = self.level;
    [self.scene addTiles];
    
    // This is the swipe handler. MyScene invokes this block whenever it
    // detects that the player performs a swipe.
    
    
    
    id block = ^(JIMCSwap *swap) {
        
        // While fruits are being matched and new fruits fall down to fill up
        // the holes, we don't want the player to tap on anything.
        self.view.userInteractionEnabled = NO;
        
        if ([self.level isPowerSwapLike:swap]){
            [self.level performSwap:swap];
            [JIMCSwapFruitSingleton sharedInstance].swap = swap;
            [self.scene animateSwap:swap completion:^{
                [self handleMatchesAll];
            }];
        }else if ([self.level isPowerSwap:swap]) {
            [self.level performSwap:swap];
            [JIMCSwapFruitSingleton sharedInstance].swap = swap;
            [self.scene animateSwap:swap completion:^{
               
                [self handleMatchesAllType:swap];
            }];
            //[self handleMatches];
        }else if ([self.level isPossibleSwap:swap]) {
            [self.level performSwap:swap];
            [JIMCSwapFruitSingleton sharedInstance].swap = swap;
            //  NSLog(@"fruta singleton ==  %@",[JIMCSwapFruitSingleton sharedInstance].fruit);
            
            [self.scene animateSwap:swap completion:^{
                [self handleMatches];
            }];
            
        } else {
            [self.scene animateInvalidSwap:swap completion:^{
                self.view.userInteractionEnabled = YES;
            }];
        }
        //[self showTurnAlert:_isMyMove];
        _isFirstRound = NO;
    };
    
    
    self.scene.swipeHandler = block;
    
    // Hide the game over panel from the screen.
    self.gameOverPanel.hidden = YES;
    
    // Present the scene.
    [skView presentScene:self.scene];
    
    // Load and start background music.
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"Mining by Moonlight" withExtension:@"mp3"];
    self.backgroundMusic = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    self.backgroundMusic.numberOfLoops = -1;
    
    if([SettingsSingleton sharedInstance].music == ON){
        [self.backgroundMusic play];
    }
    // Set ourselves as player 1 and the game to active
    _isPlayer1 = YES;
    //[self setGameState:kGameStateActive];
    [self.scene setUserInteractionEnabled:NO];
    [Nextpeer registerToSynchronizedEvent:START_GAME_SYNC_EVENT_NAME withTimetout:TIMEOUT];
//    [NetworkController sharedInstance].delegate = self;
//    [self stateChanged:[NetworkController sharedInstance].state];
//    // Let's start the game!
    //[self beginGame];
    _fruitCounter = 0;
    
    
}

- (NSArray *)fruitObjToFruitStringArray:(NSArray *)fruitObjArray{
    NSMutableArray *ret = [NSMutableArray array];
    NSMutableArray *auxRet = [NSMutableArray array];
    for (NSArray *array in fruitObjArray) {
        for (JIMCFruit *fruit in array) {
            [auxRet addObject:[fruit stringRepresentation]];
        }
        [ret addObject:[NSArray arrayWithArray:[NSArray arrayWithArray:auxRet]]];
        auxRet = [NSMutableArray array];
    }
//    for (JIMCFruit *fruit in fruitObjArray) {
//        [ret addObject:[fruit stringRepresentation]];
//    }
    return [ret copy];

}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (void) generateRandomNumber{
    self.randomNumber = arc4random();
    
}

- (void)registerNotifications{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processNextpeerDidReceiveTournamentCustomMessage:) name:@"nextpeerDidReceiveTournamentCustomMessage" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processNextpeerDidReceiveSynchronizedEvent:) name:@"nextpeerDidReceiveSynchronizedEvent" object:nil];
}



- (void)processNextpeerDidReceiveSynchronizedEvent:(NSNotification *)notification{
    NSString *eventName = [notification.userInfo objectForKey:@"eventName"];
   // NPSynchronizedEventFireReason eventFireReason = [[notification.userInfo objectForKey:@"fireReason"] intValue];
    NSLog(@"Event Firing");
    if ([START_GAME_SYNC_EVENT_NAME isEqualToString:eventName]) {
        [self generateRandomNumber];
        [NextpeerHelper sendMessageOfType:NPFruitCatchMessageSendRandomNumber DictionaryData:@{@"randomNumber" : [NSNumber numberWithInteger:_randomNumber]}];
    }
}


- (BOOL)shouldAutorotate
{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)beginGame {
    self.movesLeft = self.level.maximumMoves;
    self.score = 0;
    [self updateLabels];
    
    [self.level resetComboMultiplier];
    [self.scene animateBeginGame];
    [self shuffle];
    
    self.possibleMoves = [self.level detectPossibleSwaps];
    //self.hintAction = [SKAction sequence:@[[SKAction waitForDuration:5 withRange:0], [SKAction performSelector:@selector(showMoves) onTarget:self]]];
    
    //[self.scene runAction: self.hintAction withKey:@"Hint"];
}

- (void)beginGameForPlayer2 {
    self.movesLeft = self.level.maximumMoves;
    self.score = 0;
    [self updateLabels];
    [self.level resetComboMultiplier];
    [self.scene animateBeginGame];
    //[self shuffle];
    // Delete the old fruit sprites, but not the tiles.
    [self.scene removeAllFruitSprites];
    _isFirstRound = NO;
    
    // Fill up the level with new fruits, and create sprites for them.
   // NSSet *newFruits = [self.level shuffle];
    
    
    //self.possibleMoves = [self.level detectPossibleSwaps];
    //self.hintAction = [SKAction sequence:@[[SKAction waitForDuration:5 withRange:0], [SKAction performSelector:@selector(showMoves) onTarget:self]]];
    
    //[self.scene runAction: self.hintAction withKey:@"Hint"];
}

- (void)shuffle {
    
    // Delete the old fruit sprites, but not the tiles.
    [self.scene removeAllFruitSprites];
    
    // Fill up the level with new fruits, and create sprites for them.
    NSSet *newFruits = [self.level shuffle];
    [self.scene addSpritesForFruits:newFruits];
}

- (NSArray *)shuffledStringArrayOfFruits{
     [self.scene removeAllFruitSprites];
    NSSet * newFruits = [self.level shuffle];
    NSMutableArray *fruitStringArray = [NSMutableArray array];
    for (JIMCFruit *fruit in [newFruits allObjects]) {
        [fruitStringArray addObject:[fruit stringRepresentation]];
    }
    [self.scene addSpritesForFruits:newFruits];
    return fruitStringArray;
    
}


- (void)handleMatchesAllType:(JIMCSwap *) fruit {
    // This is the main loop that removes any matching fruits and fills up the
    // holes with new fruits. While this happens, the user cannot interact with
    // the app.
    
    [self.scene removeActionForKey:@"Hint"];
    
    // Detect if there are any matches left.
    NSSet *chains = [self.level removeMatchesAllType:fruit];
    // If there are no more matches, then the player gets to move again.
    
    if ([chains count] == 0) {
        if ((_isMyMove) && (!_isFirstRound)){
//            NSMutableArray *sendingArray = [NSMutableArray array];
//            for (NSArray *array in _arrayOfColumnArray) {
//                [sendingArray addObject:[self fruitObjToFruitStringArray:array]];
//            }
            
            [NextpeerHelper sendMessageOfType:NPFruitCatchMessageMove DictionaryData:@{@"moveColumn" : [NSNumber numberWithInt:self.scene.playerLastTouch.x],              @"moveRow" : [NSNumber numberWithInt:self.scene.playerLastTouch.y ],                 @"topUpFruits" : _parameter,
                                                                                       @"swipeColumn" : [NSNumber numberWithInt:self.scene.swipeFromLastPoint.x],
                                                                                       @"swipeRow" : [NSNumber numberWithInt:self.scene.swipeFromLastPoint.y]}];
            //_isMyMove = NO;
            _parameter = [NSMutableArray array];
            self.scene.playerLastTouch = (CGPoint){-1,-1};
            self.scene.lastTouchAssigned = NO;
            _isMyMove = NO;
            [self.view setUserInteractionEnabled:NO];
            [self showTurnAlert:NO];
        }
        else{
            if (!_isFirstRound){
                _isMyMove = YES;
                [self showTurnAlert:_isMyMove];
                [self.scene setUserInteractionEnabled:_isMyMove];
                //_arrayOfColumnArray = [NSMutableArray array];
            }
        }
        
        //_isMyMove = _isExecutingOpponentMove;
        [self beginNextTurn];
        return;

    }
    
    // First, remove any matches...
    [self.scene animateMatchedFruits:chains completion:^{
        // Add the new scores to the total.
        
        [self updateLabels];
        
        // ...then shift down any fruits that have a hole below them...
        NSArray *columns = [self.level fillHoles];
        [self.scene animateFallingFruits:columns completion:^{
            NSArray *columns;
            if (_isMyMove){
                columns = [self.level multiplayerTopUpFruits];
                [_arrayOfColumnArray addObject:columns];
                [_parameter addObjectsFromArray:self.level.parameter];
                [self.scene animateNewFruits:columns completion:^{
                    
                    // Keep repeating this cycle until there are no more matches.
                    [self handleMatches];
                }];
            }
            else{
                //columns = [_arrayOfColumnArray objectAtIndex:_fruitCounter];
                
                columns = [self.level topUpFruitsFor:_parameter];
                _parameter = [self.level.fruitTypeArray mutableCopy];
                //columns = [self.level newTopUpFruitsFor:[_arrayOfColumnArray objectAtIndex:_fruitCounter]];
                _fruitCounter++;
                [self.scene animateNewFruits:columns completion:^{
                    
                    // Keep repeating this cycle until there are no more matches.
                    [self handleMatches];
                    _auxiliaryArray = [NSMutableArray array];
                }];
            }
        }];
    }];
}
- (void)handleMatchesAll{
    // This is the main loop that removes any matching fruits and fills up the
    // holes with new fruits. While this happens, the user cannot interact with
    // the app.
    
    [self.scene removeActionForKey:@"Hint"];
    
    // Detect if there are any matches left.
    NSSet *chains = [self.level removeMatchesAll];
    // If there are no more matches, then the player gets to move again.
    
    if ([chains count] == 0) {
        if ((_isMyMove) && (!_isFirstRound)){
            NSMutableArray *sendingArray = [NSMutableArray array];
            for (NSArray *array in _arrayOfColumnArray) {
                [sendingArray addObject:[self fruitObjToFruitStringArray:array]];
            }
            
            [NextpeerHelper sendMessageOfType:NPFruitCatchMessageMove DictionaryData:@{@"moveColumn" : [NSNumber numberWithInt:self.scene.playerLastTouch.x],              @"moveRow" : [NSNumber numberWithInt:self.scene.playerLastTouch.y ],                 @"topUpFruits" : _parameter,
                                                                                       @"swipeColumn" : [NSNumber numberWithInt:self.scene.swipeFromLastPoint.x],
                                                                                       @"swipeRow" : [NSNumber numberWithInt:self.scene.swipeFromLastPoint.y]}];
            //_isMyMove = NO;
            self.scene.playerLastTouch = (CGPoint){-1,-1};
            self.scene.lastTouchAssigned = NO;
            _isMyMove = NO;
            [self.view setUserInteractionEnabled:NO];
            [self showTurnAlert:NO];
        }
        else{
            if (!_isFirstRound){
                _isMyMove = YES;
                [self showTurnAlert:_isMyMove];
                [self.scene setUserInteractionEnabled:_isMyMove];
                //_arrayOfColumnArray = [NSMutableArray array];
            }
        }
        
        //_isMyMove = _isExecutingOpponentMove;
        [self beginNextTurn];
        return;

    }

    // First, remove any matches...
    [self.scene animateMatchedFruits:chains completion:^{
        // Add the new scores to the total.
        
        [self updateLabels];
        
        // ...then shift down any fruits that have a hole below them...
        NSArray *columns = [self.level fillHoles];
        [self.scene animateFallingFruits:columns completion:^{
            NSArray *columns;
            if (_isMyMove){
                columns = [self.level multiplayerTopUpFruits];
                [_parameter addObjectsFromArray:self.level.parameter];
                [_arrayOfColumnArray addObject:columns];
                [self.scene animateNewFruits:columns completion:^{
                    
                    // Keep repeating this cycle until there are no more matches.
                    [self handleMatches];
                }];
            }
            else{
                //columns = [_arrayOfColumnArray objectAtIndex:_fruitCounter];
                columns = [self.level topUpFruitsFor:_parameter];
                 _parameter = [self.level.fruitTypeArray mutableCopy];
                [self.scene animateNewFruits:columns completion:^{
                    
                    // Keep repeating this cycle until there are no more matches.
                    [self handleMatches];
                    _auxiliaryArray = [NSMutableArray array];
                }];
            }
        }];
    }];
}

- (NSArray *)reversedFruits:(NSMutableArray *)fruits{
    NSMutableArray *mutableArray = fruits;
    NSInteger i=0;
    NSInteger j=[fruits count]-1;
    while (i<j) {
        [mutableArray exchangeObjectAtIndex:i withObjectAtIndex:j];
        i++;
        j--;
    }
    return [mutableArray copy];
    
}


- (void)handleMatches {
    // This is the main loop that removes any matching fruits and fills up the
    // holes with new fruits. While this happens, the user cannot interact with
    // the app.
    dispatch_queue_t messageQueue;
    messageQueue = dispatch_queue_create("com.valheru.messageQueue", NULL);
    
    [self.scene removeActionForKey:@"Hint"];
    // Detect if there are any matches left.
    NSSet *chains = [self.level removeMatches];
    
    // If there are no more matches, then the player gets to move again.
    if ([chains count] == 0) {
            if ((_isMyMove) && (!_isFirstRound)){
            NSMutableArray *sendingArray = [NSMutableArray array];
            for (NSArray *array in _arrayOfColumnArray) {
                [sendingArray addObject:[self fruitObjToFruitStringArray:array]];
            }
                
            [NextpeerHelper sendMessageOfType:NPFruitCatchMessageMove DictionaryData:@{@"moveColumn" : [NSNumber numberWithInt:self.scene.playerLastTouch.x],              @"moveRow" : [NSNumber numberWithInt:self.scene.playerLastTouch.y ],                 @"topUpFruits" : _parameter,
                                                                                       @"swipeColumn" : [NSNumber numberWithInt:self.scene.swipeFromLastPoint.x],
                                                                                       @"swipeRow" : [NSNumber numberWithInt:self.scene.swipeFromLastPoint.y]}];
            //_isMyMove = NO;
                self.scene.playerLastTouch = (CGPoint){-1,-1};
                self.scene.lastTouchAssigned = NO;
                _isMyMove = NO;
                [self.view setUserInteractionEnabled:NO];
                [self showTurnAlert:NO];
        }
        else{
            if (!_isFirstRound){
                _isMyMove = YES;
                [self showTurnAlert:_isMyMove];
                [self.scene setUserInteractionEnabled:_isMyMove];
                //_arrayOfColumnArray = [NSMutableArray array];
            }
        }
        
        //_isMyMove = _isExecutingOpponentMove;
        [self beginNextTurn];
        return;
    }
    
    // First, remove any matches...
    dispatch_sync(messageQueue, ^{
    [self.scene animateMatchedFruits:chains completion:^{
        // Add the new scores to the total.
        for (JIMCChain *chain in chains) {
            for (JIMCFruit *fruit in chain.fruits) {
                if ((fruit.fruitPowerUp == 1 && chain.fruits.count == 5) ||
                    (fruit.fruitPowerUp == 2 && chain.fruits.count == 4)) {
                    
                    [self.scene addSpritesForFruit:fruit];
                    [JIMCSwapFruitSingleton sharedInstance].swap = nil;
                    //break;
                }
            }
        }
        
        
        for (JIMCChain *chain in chains) {
            self.score += chain.score;
        }
        [self updateLabels];
        
        // ...then shift down any fruits that have a hole below them...
        NSArray *columns = [self.level fillHoles];
        [self.scene animateFallingFruits:columns completion:^{
            NSArray *columns;
            if (_isMyMove){
                columns = [self.level multiplayerTopUpFruits];
                [_parameter addObjectsFromArray:self.level.parameter];
                //[_arrayOfColumnArray addObject:columns];
                [self.scene animateNewFruits:columns completion:^{
                    // Keep repeating this cycle until there are no more matches.
                    [self handleMatches];
                }];
                _isExecutingOpponentMove = NO;
            }
            else{
                _isExecutingOpponentMove = YES;
                
                while ((columns == nil) || (columns.count == 0)){
                    //_arrayOfColumnArray = [self reversedFruits:_arrayOfColumnArray];
                    columns = [self.level topUpFruitsFor:_parameter];
                     _parameter = [self.level.fruitTypeArray mutableCopy];
                    
                }
                _fruitCounter++;
                
                //[self.level setI:++handleI];
                //columns = [self.level insertTopUpFruitsFor:[_arrayOfColumnArray objectAtIndex:_fruitCounter]];
                
                [self.scene animateNewFruits:columns completion:^{
                    // Keep repeating this cycle until there are no more matches.
                    [self handleMatches];
                    //_auxiliaryArray = [NSMutableArray array];
                }];
            }
        }];
    }];
    
    });
}


- (void)handlePowerUp {
    // This is the main loop that removes any matching fruits and fills up the
    // holes with new fruits. While this happens, the user cannot interact with
    // the app.
    
    // Detect if there are any matches left.
    JIMCPowerUp *powerUp = [[JIMCPowerUp alloc]init];
    powerUp.position = (CGPoint){5,5};
    NSSet *chains = [self.scene.level executePowerUp:powerUp];
    // If there are no more matches, then the player gets to move again.
    if ([chains count] == 0) {
        //NSLog(@"Chains count is zero");
        [self beginNextTurn];
        return;
    }
    // [self.level verificaDestruir:chains];
    // First, remove any matches...
    [self.scene animateMatchedFruits:chains completion:^{
        
        // Add the new scores to the total.
        for (JIMCChain *chain in chains) {
            self.score += chain.score;
        }
        [self updateLabels];
        
        // ...then shift down any fruits that have a hole below them...
        NSMutableArray *columns = [[NSMutableArray alloc]initWithArray:[self.level fillHoles]];
        
        
        
        [self.scene animateFallingFruits:columns completion:^{
            
            NSArray *columns;
            if (_isMyMove){
                columns = [self.level multiplayerTopUpFruits];
                [_parameter addObjectsFromArray:self.level.parameter];
                //[_arrayOfColumnArray addObject:columns];
                [self.scene animateNewFruits:columns completion:^{
                    // Keep repeating this cycle until there are no more matches.
                    [self handleMatches];
                }];
                _isExecutingOpponentMove = NO;
            }
            else{
                _isExecutingOpponentMove = YES;
                columns = [self.level topUpFruitsFor:_parameter];
                 _parameter = [self.level.fruitTypeArray mutableCopy];
                //columns = [self.level createTopUpFruitsFor:_arrayOfColumnArray];
                _fruitCounter++;
                [self.scene animateNewFruits:columns completion:^{
                    // Keep repeating this cycle until there are no more matches.
                    [self handleMatches];
                    //_auxiliaryArray = [NSMutableArray array];
                }];
            }
            
        }];
    }];
}


- (void)beginNextTurn {
    
    [self.level resetComboMultiplier];
    
    self.possibleMoves = [self.level detectPossibleSwaps];
    
    NSInteger i = self.possibleMoves.count;
    
    if(i == 0){
        //NSLog(@"Não há movimentos restantes.\nEmbaralhando.");
        [self shuffle];
        
        self.possibleMoves = [self.level detectPossibleSwaps];
        i = self.possibleMoves.count;
        //   NSLog(@"Jogadas possiveis = %ld",i);
    }else{
        //   NSLog(@"Jogadas possiveis = %ld",i);
    }
    
    //NSLog(@"Jogadas possiveis = %d",(int)i);
    
    //[self.scene runAction: self.hintAction withKey:@"Hint"];
    //SKAction *showMove = [SKAction repeatActionForever:[SKAction sequence:@[[SKAction waitForDuration:5 withRange:0], [SKAction performSelector:@selector(showMoves) onTarget:self]]]];
    
    //self.view.userInteractionEnabled = YES;
    //[self decrementMoves];
    
}

-(void)showMoves
{
    //Obtem um movimento possivel entre todos
    JIMCSwap *swap = [self.possibleMoves anyObject];
    
    NSInteger x,y;
    
    if(swap.fruitA.column == 4){
        x = 0;
    }else{
        x = 34 * (swap.fruitA.column - 4);
    }
    if(swap.fruitA.row == 4){
        y = 0;
    }else{
        y = 36 * (swap.fruitA.row - 4);
    }
    
//    self.hintNode = [[SKSpriteNode alloc]initWithImageNamed:[swap.fruitA highlightedSpriteName]];
//    self.hintNode.position = CGPointMake(x, y);
//    [self.scene addChild:self.hintNode];
}

- (void)updateLabels {
    self.targetLabel.text = [NSString stringWithFormat:@"%lu", (long)self.level.targetScore];
    self.movesLabel.text = [NSString stringWithFormat:@"%lu", (long)self.movesLeft];
    self.scoreLabel.text = [NSString stringWithFormat:@"%lu", (long)self.score];
    
}

- (void)decrementMoves{
    //self.movesLeft--;
    [self updateLabels];
    
    if (self.score >= self.level.targetScore) {
        self.gameOverPanel.image = [UIImage imageNamed:@"LevelComplete"];
        [self showGameOver];
    } else if (self.movesLeft == 0) {
        
        [self.scene animateGameOver];
        self.movesLeft = self.level.maximumMoves;
        self.score = 0;
        [self updateLabels];
        
    }
    
    [self.scene removeActionForKey:@"Hint"];
    
}

- (void)showGameOver {
    
    [self.scene removeActionForKey:@"Hint"];
//    if(self.hintNode){
//        [self.scene runAction:[SKAction runBlock:^{
//            [self.hintNode removeFromParent];
//        }]];
//    }
    
    
    
    self.gameOverPanel.hidden = NO;
    self.scene.userInteractionEnabled = NO;
    
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideGameOver)];
    [self.view addGestureRecognizer:self.tapGestureRecognizer];
    
    self.shuffleButton.hidden = YES;
    
}

- (void)hideGameOver {
    
    [self.scene removeActionForKey:@"Hint"];
    
    [self.view removeGestureRecognizer:self.tapGestureRecognizer];
    self.tapGestureRecognizer = nil;
    
    self.gameOverPanel.hidden = YES;
    self.scene.userInteractionEnabled = YES;
    
    [self beginGame];
    
    self.shuffleButton.hidden = NO;
    
}

- (IBAction)shuffleButtonPressed:(id)sender {
    //[self shuffle];
    
    
    // Pressing the shuffle button costs a move.
    [self decrementMoves];
    [self handlePowerUp];
    
    
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    //Metodos comentado para tirar o warning
    //UITouch *touch = [touches anyObject];
   // CGPoint point = [touch locationInNode:self.scene];
    //[[NetworkController sharedInstance] sendMovedSelf:1];
    [self.scene removeActionForKey:@"Hint"];
//    if(self.hintNode){
//        [self.scene runAction:[SKAction runBlock:^{
//            [self.hintNode removeFromParent];
//        }]];
//    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    //[self.scene runAction: self.hintAction withKey:@"Hint"];
}

-(IBAction)back:(id)sender
{
    _backButton.enabled = NO;
    [self performSegueWithIdentifier:@"Back" sender:self];
}

-(void)back {
    [self performSegueWithIdentifier:@"Back" sender:self];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([segue.identifier isEqualToString:@"Back"]){
        if(self.scene != nil)
        {
            Life *life = [Life sharedInstance];
            life.lifeCount--;
            NSDate *oldDate = life.lifeTime;
            NSTimeInterval interval = [oldDate timeIntervalSinceNow];
            NSDate *plusDate = [NSDate dateWithTimeIntervalSinceNow:interval];
            life.lifeTime = plusDate;
            [life saveToFile];
            [self.scene setPaused:YES];
            [self.scene removeAllActions];
            [self.scene removeAllChildren];
            [self.backgroundMusic stop];
            [self.scene removeAllFruitSprites];
            
            self.scene = nil;
            self.backgroundMusic = nil;
            self.level = nil;
            
            [self.scene removeFromParent];
            
            SKView *view = (SKView *)self.view;
            [view presentScene:nil];
            
            view = nil;
        }
    }
}

- (void)showTurnAlert:(BOOL)isMyTurn{
    UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"Turno" message:[NSString stringWithFormat:@"%@",isMyTurn ? @"Agora é a sua Vez!" : @"Turno do Oponente"] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alertView show];


}

-(void)processNextpeerDidReceiveTournamentCustomMessage:(NSNotification *)notification{
    
    NPTournamentCustomMessageContainer* message = (NPTournamentCustomMessageContainer*)[notification.userInfo objectForKey:@"userMessage"];
    NSLog(@"Received game message from %@", message.playerName);
    
    NSDictionary* gameMessage = [NSPropertyListSerialization propertyListWithData:message.message options:0 format:NULL error:NULL];
    int type = [[gameMessage objectForKey:@"type"] intValue];
   
    switch (type) {
            
        case NPFruitCatchMessageEventOver:
        {
            break;
        }
        case NPFruitCatchMessageSendLevel:
        {
            NSLog(@"Received Message Level");
            //NSData *fruitData = [gameMessage objectForKey:@"gameLevel"];
            NSArray *wrapperArray = [gameMessage objectForKey:@"gameLevel"];
           
            NSSet *receivedFruitSet = [self fruitObjectSetByFruitArray:wrapperArray];
            //[fruitData getBytes:&receivedFruitStruct length:pointerSize];
            
            [self beginGameForPlayer2];
            [self.scene removeAllFruitSprites];
            [self.level setFruitsBySet:receivedFruitSet];
            [self.scene addSpritesForFruits:receivedFruitSet];
            self.possibleMoves = [self.level detectPossibleSwaps];
            [NextpeerHelper sendMessageOfType:NPFruitCatchMessageBeginGame];
            [self.scene setUserInteractionEnabled:NO];
            [self showTurnAlert:NO];
            _isMyMove = NO;
            break;
            
        }
        case NPFruitCatchMessageSendRandomNumber:
        {
            NSLog(@"Received Random Number");
            //NSDictionary *dict = [NSDictionary alloc]init
            NSDictionary *parameterDict = @{playerIdKey : message.playerId,
                                            randomNumberKey : [gameMessage objectForKey:@"randomNumber"]
                                            };
           if (![_orderOfPlayers containsObject:parameterDict]){
               [_orderOfPlayers addObject:parameterDict];
            }
            
            if ([[gameMessage objectForKey:@"randomNumber"] intValue] == _randomNumber) {
                //2
                
                NSLog(@"Tie");
                _randomNumber = arc4random();
                [self generateRandomNumber];
                
                [NextpeerHelper sendMessageOfType:NPFruitCatchMessageSendRandomNumber DictionaryData:@{@"randomNumber" : [NSNumber numberWithInt:self.randomNumber]}];
            } else {
                //3
                NSLog(@"Opponent Number = %ld",(long)[[gameMessage objectForKey:@"randomNumber"] intValue]);
                    if (self.randomNumber > [[gameMessage objectForKey:@"randomNumber"] intValue]){
                        [self beginGame];
                        [self.scene setUserInteractionEnabled:NO];
                        //NSData *dataFromSet = [NSData dataWithBytes:&shuffledFruitStruct length:sizeof(shuffledFruitStruct)];
                        NSArray *wrapperArray = [self shuffledStringArrayOfFruits];
                        //NSLog(@"Wrapper Array of Sender: %@",wrapperArray);
                        [NextpeerHelper sendMessageOfType:NPFruitCatchMessageSendLevel DictionaryData:@{@"gameLevel" : wrapperArray,
                                           }];
                    [self showTurnAlert:YES];
                    _isMyMove = YES;
                   }
                
        }
        break;
        }
        case NPFruitCatchMessageBeginGame:
        {
            [self.scene setUserInteractionEnabled:YES];
            break;
        }
        case NPFruitCatchMessageMove:
        {
            NSLog(@"Received Message Move");
            _isMyMove = NO;
            CGPoint oponentLocation = CGPointMake([[gameMessage objectForKey:@"moveColumn"] intValue], [[gameMessage objectForKey:@"moveRow"] intValue]);
            CGPoint opponentSwipe = CGPointMake([[gameMessage objectForKey:@"swipeColumn"] intValue], [[gameMessage objectForKey:@"swipeRow"] intValue]);
            _parameter = [gameMessage objectForKey:@"topUpFruits"];
            //_arrayOfColumnArray = [gameMessage objectForKey:@"topUpFruits"];
            //_arrayOfColumnArray = [self fruitStringRepresentationArrayToObjArray];
            [self.scene touchAtColumRowCGPoint:oponentLocation OpponentSwipe:opponentSwipe];
            
            _fruitCounter = 0;
            [self.view setUserInteractionEnabled:YES];
            //_parameter = [NSMutableArray array];
            
            break;
        }
        
    }
}

- (NSMutableArray *)fruitStringRepresentationArrayToObjArray{
    NSMutableArray *ret = [NSMutableArray array];
    NSMutableArray *auxiliaryArray = [NSMutableArray array];
    NSMutableArray *auxiliaryArray2 = [NSMutableArray array];
    int i,j,k;
    i=j=k=0;
    for (NSArray *array in _arrayOfColumnArray) {
        for (NSArray *array2 in array) {
            for (NSString *str in array2) {
                //[[[_arrayOfColumnArray objectAtIndex:i] objectAtIndex:j] replaceObjectAtIndex:k withObject:[JIMCFruit fruitByStringRepresentation:str]];
                [auxiliaryArray addObject:[JIMCFruit fruitByStringRepresentation:str]];
                //k++;
            }
            [auxiliaryArray2 addObject:[auxiliaryArray copy]];
            auxiliaryArray = [NSMutableArray array];
            //j++;
        }
        [ret addObject:[auxiliaryArray2 copy]];
        auxiliaryArray2 = [NSMutableArray array];
        
    }
    return ret;
}

- (NSSet *)fruitObjectSetByFruitArray:(NSArray *)fruitArray{
    NSMutableSet *ret = [NSMutableSet set];
    for (NSString *stringRepresentation in fruitArray) {
        [ret addObject:[JIMCFruit fruitByStringRepresentation:stringRepresentation]];
    }
    return [ret copy];
    
}

@end