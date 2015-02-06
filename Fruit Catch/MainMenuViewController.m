//
//  MainMenuViewController.m
//  Fruit Catch
//
//  Created by Júlio Menezes Noronha on 28/11/14.
//  Copyright (c) 2014 Caio de Souza. All rights reserved.
//

#import "MainMenuViewController.h"
#import "SettingsSingleton.h"
#import "AppUtils.h"
#import "RNEncryptor.h"
#import "NetworkController.h"

#define USER_SECRET @"0x444F@c3b0ok"
#define ON 1
#define OFF 0

@interface MainMenuViewController ()

@property (nonatomic) IBOutlet UIButton *musicBtn;
@property (nonatomic) IBOutlet UIButton *soundBtn;
@property (nonatomic) IBOutlet UIButton *singlePlayerBtn;
@property (nonatomic) IBOutlet UIButton *multiplayerBtn;
@property (nonatomic) IBOutlet UIButton *settingsBtn;
@property (nonatomic) IBOutlet UIImageView *nome;
@property (nonatomic) UIView *configuracao;
@property (nonatomic) BOOL option;

@end

@implementation MainMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.loginView.readPermissions = @[@"public_profile", @"email", @"user_friends"];
    _loginView.delegate = self;
    UIImageView *fundo = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"Agrupar-1.png"]];
    fundo.center = self.view.center;
    [self.view insertSubview:fundo atIndex:0];
    self.nome = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"logo"]];
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"Launch"] == YES){
        self.nome.center = CGPointMake(self.view.center.x, self.view.center.y-400);
        [UIView animateWithDuration:2
                              delay:0.75
             usingSpringWithDamping:0.35
              initialSpringVelocity:0
                            options:0
                         animations:^{
                            self.nome.center = CGPointMake(self.view.center.x, self.view.center.y-200);
                         }
                         completion:nil];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"Launch"];
    }else{
        self.nome.center = CGPointMake(self.view.center.x, self.view.center.y-200);
    }

    [self.view insertSubview:self.nome atIndex:1];
    
    self.configuracao = [[UIView alloc]initWithFrame:(CGRectMake(self.view.frame.origin.x, CGRectGetMinY(self.view.frame)-300, self.view.frame.size.height/2, self.view.frame.size.width/1.5))];
    
    UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(50, 50, 100, 100)];
    label.backgroundColor = [UIColor whiteColor];
    [self.configuracao addSubview:label];
    [self.configuracao setBackgroundColor:[UIColor blackColor]];
    [self.view addSubview:self.configuracao];
    
}

-(void)viewWillAppear:(BOOL)animated
{
    //Some com os botões de musica e sons
    self.soundBtn.enabled = NO;
    self.soundBtn.alpha   = 0;
    
    self.musicBtn.enabled = NO;
    self.musicBtn.alpha   = 0;
    
    self.option = NO;
    //Anima os botões single, multiplayer e options
    [UIView animateWithDuration:1
                          delay:0
                        options:UIViewKeyframeAnimationOptionAutoreverse | UIViewKeyframeAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut | UIViewKeyframeAnimationOptionAllowUserInteraction
                     animations:^{
                         
                         //Single
                         self.singlePlayerBtn.transform = CGAffineTransformMakeScale(1.02, 1.02);
                         //Multi
                         self.multiplayerBtn.transform  = CGAffineTransformMakeScale(1.02, 1.02);
                         //Options
                         self.settingsBtn.transform     = CGAffineTransformMakeRotation(M_PI_4 / 4);
                     }completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)options:(id)sender
{
    if(!self.option){
        [UIView animateWithDuration:1.5
                              delay:0
             usingSpringWithDamping:0.65
              initialSpringVelocity:0
                            options:0
                         animations:^{
                             self.configuracao.center = CGPointMake(self.view.center.x, self.view.center.y);
                         }completion:^(BOOL fisished){
                             self.option = YES;
                         }];
        
        /*
        self.musicBtn.enabled = YES;
        self.musicBtn.alpha   = 1;
        
        self.soundBtn.enabled = YES;
        self.soundBtn.alpha   = 1;
        */
        //Fazer a animacao dos botoes surgindo
        
        
    }else{
        
        [UIView animateWithDuration:1.5
                              delay:0
             usingSpringWithDamping:0.65
              initialSpringVelocity:0
                            options:0
                         animations:^{
                             self.configuracao.center = CGPointMake(self.configuracao.center.x, CGRectGetMinY(self.view.frame)-300);
                         }completion:^(BOOL fisished){
                             self.option = NO;
                         }];
        

        /*
        self.musicBtn.enabled = NO;
        self.musicBtn.alpha   = 0;
        
        self.soundBtn.enabled = NO;
        self.soundBtn.alpha   = 0;
        */
        
    }
    
    
    
    
    
}

-(IBAction)singlePlayer:(id)sender
{
    _singlePlayerButton.enabled = NO;
    [self performSegueWithIdentifier:@"Single" sender:self];
}

-(IBAction)multiplayer:(id)sender
{
    NSLog(@"Multiplayer");
    [[NetworkController sharedInstance] authenticateLocalUser];
    [[NetworkController sharedInstance] findMatchWithMinPlayers:2 maxPlayers:2 viewController:self];
}

-(IBAction)musicON_OFF:(id)sender
{
    [[SettingsSingleton sharedInstance] musicON_OFF];
    [self.view setNeedsDisplay];
}

-(IBAction)soundON_OFF:(id)sender
{
    [[SettingsSingleton sharedInstance] soundON_OFF];

}

- (void)loginViewFetchedUserInfo:(FBLoginView *)loginView
                            user:(id<FBGraphUser>)user {
    self.profilePictureView.profileID = user.objectID;
    self.nameLabel.text = user.name;
    NSLog(@"User ID = %@",user.objectID);
    NSDictionary *userDict = @{@"facebookID" : user.objectID,
                               @"alias" : user.name
                               };
    
    NSLog(@"USER = %@", user);
    
    NSString *filePath = [AppUtils getAppDataDir];
    //NSLog(@"%@",self.lives);
    NSData *dataToSave = [NSKeyedArchiver archivedDataWithRootObject:userDict];
    NSError *error;
    NSData *encryptedData = [RNEncryptor encryptData:dataToSave
                                        withSettings:kRNCryptorAES256Settings
                                            password:USER_SECRET
                                               error:&error];

    [[FBRequest requestForMe] startWithCompletionHandler:^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *FBuser, NSError *error) {
        if (error) {
            // Handle error
        }
        
        else {
            NSString *userName = [FBuser name];
            NSString *userImageURL = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=large", [FBuser objectID]];

            
            NSLog(@"IMAGEM = %@", userImageURL);
            NSLog(@"USERNAME = %@", userName);
        }
    }];
    
    [FBRequestConnection startWithGraphPath:@"me/friends" parameters:nil HTTPMethod:@"GET" completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        
        NSArray *data  = [result objectForKey:@"data"];
        
        for (NSDictionary *oi in data) {
            NSLog(@"name = %@",[oi objectForKey:@"name"]);
        }
    }];
    
    BOOL sucess = [encryptedData writeToFile:filePath atomically:YES];
    if (!sucess){
        NSLog(@"Erro ao Salvar arquivo de Usuário");
    }
    else{
        
    
    }
   
    
}

- (void)loginViewShowingLoggedInUser:(FBLoginView *)loginView {
    self.statusLabel.text = @"You're logged in as";
}

- (void)loginViewShowingLoggedOutUser:(FBLoginView *)loginView {
    self.profilePictureView.profileID = nil;
    self.nameLabel.text = @"";
    self.statusLabel.text= @"You're not logged in!";
}

- (void)loginView:(FBLoginView *)loginView handleError:(NSError *)error {
    NSString *alertMessage, *alertTitle;
    
    // If the user should perform an action outside of you app to recover,
    // the SDK will provide a message for the user, you just need to surface it.
    // This conveniently handles cases like Facebook password change or unverified Facebook accounts.
    if ([FBErrorUtility shouldNotifyUserForError:error]) {
        alertTitle = @"Facebook error";
        alertMessage = [FBErrorUtility userMessageForError:error];
        
        // This code will handle session closures that happen outside of the app
        // You can take a look at our error handling guide to know more about it
        // https://developers.facebook.com/docs/ios/errors
    } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryAuthenticationReopenSession) {
        alertTitle = @"Session Error";
        alertMessage = @"Your current session is no longer valid. Please log in again.";
        
        // If the user has cancelled a login, we will do nothing.
        // You can also choose to show the user a message if cancelling login will result in
        // the user not being able to complete a task they had initiated in your app
        // (like accessing FB-stored information or posting to Facebook)
    } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled) {
        NSLog(@"user cancelled login");
        
        // For simplicity, this sample handles other errors with a generic message
        // You can checkout our error handling guide for more detailed information
        // https://developers.facebook.com/docs/ios/errors
    } else {
        alertTitle  = @"Something went wrong";
        alertMessage = @"Please try again later.";
        NSLog(@"Unexpected error:%@", error);
    }
    
    if (alertMessage) {
        [[[UIAlertView alloc] initWithTitle:alertTitle
                                    message:alertMessage
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
