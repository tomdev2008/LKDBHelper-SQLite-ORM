//
//  NSObject+LKModel.m
//  LKDBHelper
//
//  Created by upin on 13-4-15.
//  Copyright (c) 2013年 ljh. All rights reserved.
//

#import "NSObject+LKModel.h"



static char LKModelBase_Key_RowID;
@implementation NSObject (LKModel)

+(NSDictionary *)getPropertys
{
    static __strong NSMutableDictionary* oncePropertyDic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        oncePropertyDic = [[NSMutableDictionary alloc]initWithCapacity:8];
    });
    NSDictionary* props = [oncePropertyDic objectForKey:NSStringFromClass(self)];
    if(props == nil)
    {
        NSMutableArray* pronames = [NSMutableArray array];
        NSMutableArray* protypes = [NSMutableArray array];
        NSMutableArray* sqltypes = [NSMutableArray array];
        
        props = [NSDictionary dictionaryWithObjectsAndKeys:pronames,@"name",protypes,@"type",sqltypes,@"sqltype",nil];
        [self getSelfPropertys:pronames protypes:protypes];
        
        [oncePropertyDic setObject:props forKey:NSStringFromClass(self)];
    }
    return props;
}
+(BOOL)isContainParent
{
    return NO;
}

/**
 *	@brief	获取自身的属性
 *
 *	@param 	pronames 	保存属性名称
 *	@param 	protypes 	保存属性类型
 */
+ (void)getSelfPropertys:(NSMutableArray *)pronames protypes:(NSMutableArray *)protypes
{
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(self, &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        if([propertyName isEqualToString:@"primaryKey"]||[propertyName isEqualToString:@"rowid"])
        {
            continue;
        }
        [pronames addObject:propertyName];
        NSString *propertyType = [NSString stringWithCString: property_getAttributes(property) encoding:NSUTF8StringEncoding];
        /*
         c char
         i int
         l long
         s short
         d double
         f float
         @ id //指针 对象
         ...  BOOL 获取到的表示 方式是 char
         .... ^i 表示  int*  一般都不会用到
         */
        
        if ([propertyType hasPrefix:@"T@"]) {
            [protypes addObject:[propertyType substringWithRange:NSMakeRange(3, [propertyType rangeOfString:@","].location-4)]];
        }
        else if([propertyType hasPrefix:@"T{"])
        {
            [protypes addObject:[propertyType substringWithRange:NSMakeRange(2, [propertyType rangeOfString:@"="].location-2)]];
        }
        else
        {
            propertyType = [propertyType lowercaseString];
            if ([propertyType hasPrefix:@"ti"])
            {
                [protypes addObject:@"int"];
            }
            else if ([propertyType hasPrefix:@"tf"])
            {
                [protypes addObject:@"float"];
            }
            else if([propertyType hasPrefix:@"td"]) {
                [protypes addObject:@"double"];
            }
            else if([propertyType hasPrefix:@"tl"])
            {
                [protypes addObject:@"long"];
            }
            else if ([propertyType hasPrefix:@"tc"]) {
                [protypes addObject:@"char"];
            }
            else if([propertyType hasPrefix:@"ts"])
            {
                [protypes addObject:@"short"];
            }
            else {
                [protypes addObject:@"NSString"];
            }
        }
    }
    free(properties);
    if([self isContainParent] && [self superclass] != [NSObject class])
    {
        [[self superclass] getSelfPropertys:pronames protypes:protypes];
    }
}

+(NSString *)getPrimaryKey
{
    return nil;
}
+(NSString *)getPrimaryKeyType
{
    static NSString* primaryKeyType;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString* primarykey = [self getPrimaryKey];
        if ([LKDBUtils checkStringIsEmpty:primarykey]) {
            NSLog(@"#error %@ primary key is nil",NSStringFromClass(self));
            return;
        }
        NSDictionary* dic  = [self getPropertys];
        NSArray* pronames = [dic objectForKey:@"name"];
        NSArray* protypes = [dic objectForKey:@"type"];
        int index = [pronames indexOfObject:primarykey];
        if(index == NSNotFound)
        {
            NSLog(@"#error %@ primary key is invalid ....!",NSStringFromClass(self));
            return;
        }
        primaryKeyType = [protypes objectAtIndex:index];
    });
    return primaryKeyType;
}
-(id)getPrimaryValue
{
    NSString* primarykey = [self.class getPrimaryKey];
    NSString* primaryType = [self.class getPrimaryKeyType];
    
    if(primarykey&&primaryType)
    {
        return [self modelGetValueWithKey:primarykey type:primaryType];
    }
    return nil;
}
+(NSString *)getTableName
{
    return nil;
}

#pragma mark- translate value
+(NSString *)getDBImagePathWithName:(NSString *)filename
{
    NSString* dir = [NSString stringWithFormat:@"dbimg/%@",NSStringFromClass(self)];
    return [LKDBUtils getPathForDocuments:filename inDir:dir];
}
+(NSString*)getDBDataPathWithName:(NSString *)filename
{
    NSString* dir = [NSString stringWithFormat:@"dbdata/%@",NSStringFromClass(self)];
    return [LKDBUtils getPathForDocuments:filename inDir:dir];
}

-(id)modelGetValueWithKey:(NSString *)key type:(NSString *)columeType
{
    id value = [self valueForKey:key];
    if([value isKindOfClass:[UIImage class]])
    {
        long random = arc4random();
        long date = [[NSDate date] timeIntervalSince1970];
        NSString* filename = [NSString stringWithFormat:@"img%ld%ld",date&0xFFFFF,random&0xFFF];
        
        NSData* datas = UIImageJPEGRepresentation(value, 1);
        [datas writeToFile:[self.class getDBImagePathWithName:filename] atomically:YES];
        value = filename;
    }
    else if([value isKindOfClass:[NSData class]])
    {
        long random = arc4random();
        long date = [[NSDate date] timeIntervalSince1970];
        NSString* filename = [NSString stringWithFormat:@"data%ld%ld",date&0xFFFFF,random&0xFFF];
        
        [value writeToFile:[self.class getDBDataPathWithName:filename] atomically:YES];
        value = filename;
    }
    else if([value isKindOfClass:[NSDate class]])
    {
        value = [LKDBUtils stringWithDate:value];
    }
    else if([value isKindOfClass:[UIColor class]])
    {
        UIColor* color = value;
        float r,g,b,a;
        [color getRed:&r green:&g blue:&b alpha:&a];
        value = [NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f",r,g,b,a];
    }
    else if([columeType isEqualToString:@"char"])
    {
        value = [value stringValue];
    }
    else if([columeType isEqualToString:@"float"])
    {
        value = [value stringValue];
    }
    else if([columeType isEqualToString:@"CGRect"])
    {
        value = NSStringFromCGRect([value CGRectValue]);
    }
    else if([columeType isEqualToString:@"CGPoint"])
    {
        value = NSStringFromCGPoint([value CGPointValue]);
    }
    else if([columeType isEqualToString:@"CGSize"])
    {
        value = NSStringFromCGSize([value CGSizeValue]);
    }
    return value;
}

-(void)modelSetValue:(id)value key:(NSString *)key type:(NSString *)columeType
{
    id modelValue = value;
    if([columeType isEqualToString:@"UIImage"])
    {
        NSString* filename = value;
        NSString* filepath = [self.class getDBImagePathWithName:filename];
        if([LKDBUtils isFileExists:filepath])
        {
            UIImage* img = [UIImage imageWithContentsOfFile:filepath];
            modelValue = img;
        }
    }
    else if([columeType isEqualToString:@"NSDate"])
    {
        NSString* datestr = value;
        modelValue = [LKDBUtils dateWithString:datestr];
    }
    else if([columeType isEqualToString:@"NSData"])
    {
        NSString* filename = value;
        NSString* filepath = [self.class getDBDataPathWithName:filename];
        if([LKDBUtils isFileExists:filepath])
        {
            NSData* data = [NSData dataWithContentsOfFile:filepath];
            modelValue = data;
        }
    }else if([columeType isEqualToString:@"UIColor"])
    {
        NSString* color = value;
        NSArray* array = [color componentsSeparatedByString:@","];
        float r,g,b,a;
        r = [[array objectAtIndex:0] floatValue];
        g = [[array objectAtIndex:1] floatValue];
        b = [[array objectAtIndex:2] floatValue];
        a = [[array objectAtIndex:3] floatValue];
        
        modelValue = [UIColor colorWithRed:r green:g blue:b alpha:a];
    }
    else if([columeType isEqualToString:@"CGRect"])
    {
        modelValue = [NSValue valueWithCGRect:CGRectFromString(value)];
    }
    else if([columeType isEqualToString:@"CGPoint"])
    {
        modelValue = [NSValue valueWithCGPoint:CGPointFromString(value)];
    }
    else if([columeType isEqualToString:@"CGSize"])
    {
        modelValue = [NSValue valueWithCGSize:CGSizeFromString(value)];
    }
    
    [self setValue:modelValue forKey:key];
}

#pragma mark -
-(void)setRowid:(int)rowid
{
    objc_setAssociatedObject(self, &LKModelBase_Key_RowID,[NSNumber numberWithInt:rowid], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(int)rowid
{
    return [objc_getAssociatedObject(self, &LKModelBase_Key_RowID) intValue];
}

-(NSString*)printAllPropertys
{
    NSMutableString* sb = [NSMutableString stringWithCapacity:0];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    [sb appendFormat:@"\n %@ : %@ ",@"rowid",[self valueForKey:@"rowid"]];
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        [sb appendFormat:@"\n %@ : %@ ",propertyName,[self valueForKey:propertyName]];
    }
    free(properties);
    NSLog(@"%@",sb);
    return sb;
}

#pragma mark version manager
//版本号  最少为1
+(int)getTableVersion
{
    return 1;
}
+(LKTableUpdateType)tableUpdateWithDBHelper:(LKDBHelper *)helper oldVersion:(int)oldVersion newVersion:(int)newVersion
{
    return LKTableUpdateTypeDefault;
}
@end