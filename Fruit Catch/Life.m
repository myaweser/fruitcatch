//
//  Life.m
//  Fruit Catch
//
//  Created by Caio de Souza on 09/12/14.
//  Copyright (c) 2014 Caio de Souza. All rights reserved.
//

#import "Life.h"
#import "RNDecryptor.h"
#import "RNEncryptor.h"
#import "AppUtils.h"
#define SECRET @"0x777C4f3"
#define USER_SECRET @"0x444F@c3b0ok"
#define MULTIPLAYER_SECRET @"0xSt4rWar$"

static Life *instance;

@implementation Life

- (id) initWithCoder:(NSCoder *)aDecoder{
    self = [super init];
    if (self){
        self.lifeCount = [aDecoder decodeIntegerForKey:@"lifeCount"];
        self.lifeTime = [aDecoder decodeObjectForKey:@"lifeTime"];
        self.timerMinutes = [aDecoder decodeIntForKey:@"timerMinutes"];
        self.timerSeconds = [aDecoder decodeIntForKey:@"timerSeconds"];
        self.minutesPassed = [aDecoder decodeIntForKey:@"minutesPassed"];
        self.secondsPassed = [aDecoder decodeIntForKey:@"secondsPassed"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder{
    [aCoder encodeInteger:self.lifeCount forKey:@"lifeCount"];
    [aCoder encodeObject:self.lifeTime forKey:@"lifeTime"];
    [aCoder encodeInt:self.timerMinutes forKey:@"timerMinutes"];
    [aCoder encodeInt:self.timerSeconds forKey:@"timerSeconds"];
    [aCoder encodeInt:self.minutesPassed forKey:@"minutesPassed"];
    [aCoder encodeInt:self.secondsPassed forKey:@"secondsPassed"];
}

+ (Life *)sharedInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[Life alloc]initFromFile];
    });
    return instance;
}


- (instancetype)initFromFile{
    
        self = [super init];
        if (self){
            NSString *appDataDir = [AppUtils getAppLifeDir];
            if ([[NSFileManager defaultManager] fileExistsAtPath:appDataDir]) {
                NSData *data = [NSData dataWithContentsOfFile:appDataDir];
                NSError *error;
                NSData *decryptedData = [RNDecryptor decryptData:data withPassword:SECRET error:&error];
                if (!error){
                    self = [NSKeyedUnarchiver unarchiveObjectWithData:decryptedData];
                }
                else{
                    self = [[Life alloc]initFromZero];
                }
            }
            else{
                self = [[Life alloc]initFromZero];
            }

        }
        return self;
}

- (instancetype) initFromZero{
    self = [super init];
    if (self){
        self.lifeCount = 5;
        self.timerSeconds = 0;
        self.timerMinutes = 0;
        self.minutesPassed = 0;
        self.secondsPassed = 0;
        self.lifeTime = [NSDate date];
    }
    return self;
}

- (NSString *)description{
    return [NSString stringWithFormat:@"Life Object:\n Life Count = %ld - Life Time = %@,\n Timer Minute = %d  - Timer Seconds = %d/nMinutes Passed = %d   - Seconds Passed = %d",(long)self.lifeCount,self.lifeTime,self.timerMinutes,self.timerSeconds,self.minutesPassed,self.secondsPassed];
}

- (void)loadFromFile{
    NSString *appDataDir = [AppUtils getAppLifeDir];
    if ([[NSFileManager defaultManager] fileExistsAtPath:appDataDir]) {
        NSData *data = [NSData dataWithContentsOfFile:appDataDir];
        NSError *error;
        NSData *decryptedData = [RNDecryptor decryptData:data withPassword:SECRET error:&error];
        if (!error){
            Life *obj = [NSKeyedUnarchiver unarchiveObjectWithData:decryptedData];
            
            self.lifeCount = obj.lifeCount;
            self.lifeTime = obj.lifeTime;
            self.timerMinutes = 0;
            self.timerSeconds = 0;
            self.minutesPassed = obj.minutesPassed;
            self.secondsPassed = obj.secondsPassed;
        }
    }
    
}

- (void)saveToFile{
    NSString *filePath = [AppUtils getAppLifeDir];
    //NSLog(@"%@",self.lives);
    NSData *dataToSave = [NSKeyedArchiver archivedDataWithRootObject:self];
    NSError *error;
    NSData *encryptedData = [RNEncryptor encryptData:dataToSave
                                        withSettings:kRNCryptorAES256Settings
                                            password:SECRET
                                               error:&error];
    
    BOOL sucess = [encryptedData writeToFile:filePath atomically:YES];
    if (!sucess){
        NSLog(@"Erro ao Salvar arquivo de Vidas");
    }
}

@end
