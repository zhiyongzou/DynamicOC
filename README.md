![visitors](https://visitor-badge.laobi.icu/badge?page_id=zhiyongzou.dynamic.oc)
![Objective-C](https://img.shields.io/badge/language-Objective--C-orange.svg)

# 深入理解 iOS 热修复原理


## 背景
顾名思义热修复就是使 App 具备线上修复 bug 的能力，但是遗憾的是苹果出于安全的考虑禁用了热修复。虽然 App 审核加快了，但是依然无法很好的控制线上 bug 的影响范围。由于 JSPatch 存在审核风险，所以我们需要另辟蹊径，自研一套适合自己的热修复框架。

## 目标
大部分线上 bug 并不需要完全替换原方法实现才能修复问题，我们可以在原来的方法实现前后增加一些自定的方法调用，或者是修改原方法的调用参数，或者是修改其内部的某一个方法调用即可修复问题。

```objc
- (void)sayHelloTo:(NSString *)name
{
    // 当 name = nil 会发生 nil 异常。所以我们需要加一个 nil 保护逻辑
    // 像这种情况就不需要完全替换原方法实现，只需要在该方法调用前增加一个 if 条件语句即可
    
    //fix code
//  if (name == nil) {
//      return;
//  }
    
    [self.nameList addObject:name];
    NSLog(@"Hello %@", name);
}

```

综上所述，热修复只需要具备以下几点即可：

1. 方法替换为空实现
2. 方法参数修改
3. 方法返回值修改
4. 方法调用前后插入自定义代码
	* 支持任意 OC 方法调用
	* 支持赋值语句
	* 支持 if 语句：**==、!=、>、>=、<、<=、||、&&**
	* 支持 super 调用
	* 支持自定义局部变量
	* 支持 return 语句

## 原理
热修复的核心原理：

1. 拦截目标方法调用，让其调用转发到预先埋好的特定方法中
2. 获取目标方法的调用参数

只要完成了上面两步，你就可以随心所欲了。在肆意发挥前，你需要掌握一些 Runtime 的基础理论，下面进入 Runtime 理论速成教程。

### Runtime 速成
Runtime 可以在运行时去动态的创建类和方法，因此你可以通过字符串反射的方式去动态调用OC方法、动态的替换方法、动态新增方法等等。下面简单介绍下热修复所需要用到的 Runtime 知识点。

#### Class 反射创建
通过字符串创建类：Class

```objc
// 方式1
NSClassFromString(@"NSObject");

// 方式2 
objc_getClass("NSObject");
```

#### SEL 反射创建
通过字符串创建方法 selector

```objc
// 方式1
@selector(init);

// 方式2
sel_registerName("init");

// 方式3
NSSelectorFromString(@"init");
```

#### 方法替换/交换
- 方法替换：`class_replaceMethod`
- 方法交换：`method_exchangeImplementations`

```objc
// 方法替换
- (void)methodReplace
{
    Method methodA = class_getInstanceMethod(self.class, @selector(myMethodA));
    IMP impA = method_getImplementation(methodA);
    class_replaceMethod(self.class, @selector(myMethodC), impA, method_getTypeEncoding(methodA));
    
    // print: myMethodA
    [self myMethodC];
}

// 方法交换
- (void)methodExchange
{
    Method methodA = class_getInstanceMethod(self.class, @selector(myMethodA));
    Method methodB = class_getInstanceMethod(self.class, @selector(myMethodB));
    method_exchangeImplementations(methodA, methodB);
    
    // print: myMethodB
    [self myMethodA];
    
    // print: myMethodA
    [self myMethodB];
}

- (void)myMethodA
{
    NSLog(@"myMethodA");
}

- (void)myMethodB
{
    NSLog(@"myMethodB");
}

- (void)myMethodC
{
    NSLog(@"myMethodC");
}
```

#### 新增类
通过字符串动态新增一个类

1. 首先创建新类：`objc_allocateClassPair`
2. 然后注册新创建的类：`objc_registerClassPair`

这里有个小知识点，为什么类创建的方法名是`objc_allocateClassPair`，而不是`objc_allocateClass`呢？这是因为它同时创建了一个类(class)和元类(metaclass)。关于元类可以看这篇文章：[What is a meta-class in Objective-C?](https://www.cocoawithlove.com/2010/01/what-is-meta-class-in-objective-c.html)

```objc
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self addNewClassPair];
    
    Class MyObject = NSClassFromString(@"MyObject");
    NSObject *myObj = [[MyObject alloc] init];
    [myObj performSelector:@selector(sayHello)];

    return YES;
}

- (void)addNewClassPair
{
    Class myCls = objc_allocateClassPair([NSObject class], "MyObject", 0);
    objc_registerClassPair(myCls);
    [self addNewMethodWithClass:myCls];
}
```

#### 新增方法

新增方法：`class_addMethod`

这里也有个小知识点，就是使用特定字符串描述方法返回值和参数，例如：`v@:`。其具体映射关系请移步：[Type Encodings](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100-SW1)

```objc
void sayHello(id self, SEL _cmd)
{
    NSLog(@"%@ %s", self, __func__);
}

- (void)addNewMethodWithClass:(Class)targetClass
{
    class_addMethod(targetClass, @selector(sayHello), (IMP)sayHello, "v@:");
}
```

#### 消息转发

当给对象发送消息时，如果对象没有找到对应的方法实现，那么就会进入正常的消息转发流程。其主要流程如下：

```objc
// 1.运行时动态添加方法
+ (BOOL)resolveInstanceMethod:(SEL)sel 
 
// 2.快速转发
- (id)forwardingTargetForSelector:(SEL)aSelector
 
// 3.构建方法签名
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector

// 4.消息转发
- (void)forwardInvocation:(NSInvocation *)anInvocation

```

其中最后的`forwardInvocation:`会传递一个`NSInvocation`对象（**Ps：NSInvocation 可以理解为是消息发送`objc_msgSend(void id self, SEL op, ...  )`的对象**）。NSInvocation 包含了这个方法调用的所有信息：selector、参数类型、参数值和返回值类型。此外，你还可以去更改参数值和返回值。

**除了上面的正常消息转发，我们还可以借助`_objc_msgForward`方法让消息强制转发**

```objc
Method methodA = class_getInstanceMethod(self.class, @selector(myMethodA));
IMP msgForwardIMP = _objc_msgForward;

// 替换 myMethodA 的实现后，每次调用 myMethodA 都会进入消息转发
class_replaceMethod(self.class, @selector(myMethodA), msgForwardIMP, method_getTypeEncoding(methodA));
```

### Method 调用方式

1. 常规调用
2. 反射调用
3. objc_msgSend 
4. C 函数调用
5. NSInvocation 调用

```objc
@interface People : NSObject

- (void)helloWorld;

@end

// 常规调用
People *people = [[People alloc] init];
[people helloWorld];

// 反射调用    
Class cls = NSClassFromString(@"People");
id obj = [[cls alloc] init];
[obj performSelector:NSSelectorFromString(@"helloWorld")];

// objc_msgSend
((void(*)(id, SEL))objc_msgSend)(people, sel_registerName("helloWorld"));

// C 函数调用
Method initMethod = class_getInstanceMethod([People class], @selector(helloWorld));
IMP imp = method_getImplementation(initMethod);
((void (*) (id, SEL))imp)(people, @selector(helloWorld));

// NSInvocation 调用
NSMethodSignature *sig = [[People class] instanceMethodSignatureForSelector:sel_registerName("helloWorld")];
NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
invocation.target = people;
invocation.selector = sel_registerName("helloWorld");
[invocation invoke];
```

第五种 **NSInvocation 调用** 是热修复调用任意 OC 方法的核心基础。通过 NSInvocation 不但可以自定义函数的参数值和返回值，而且还可以自定义方法选择器（selector） 和消息接收对象（target）。因此，我们可以通过字符串的方式构建任意 OC 方法调用。


## 实战
掌握了理论知识后，实践起来就不难了。上面说到热修复的核心就是**拦截目标方法调用**并且拿到**方法的参数值**，要实现这一点其实很容易。具体步骤如下：

1. 首先新增一个方法实现跟目标方法一致的别名方法，用来调用原目标方法。
2. 其次将目标方法的函数实现（IMP）替换成 `_objc_msgForward`，目的是让目标方法进行强制转发
3. 最后将目标方法类的`forwardInvocation:`方法实现替换成通用的自定义实现，其目的是可以在这个自定义实现里面拿到目标方法的 `NSInvocation` 对象。

下面是热修复核心代码的简要实现。

> 实战部分给出的示例代码不考虑异常等情况，只为阐明热修复原理

```objc
typedef void(^OCDynamicBlock)(id self, NSInvocation *originalInvocation);

@implementation NSObject (OCDynamic)

+ (void)dy_hookSelector:(SEL)selector withBlock:(void(^)(id self, NSInvocation *originalInvocation))block
{
    // 保存回调 block
    [dynamicBlockMap() setObject:block forKey:NSStringFromSelector(selector)];
    
    // 1.获取目标方法的 IMP
    Method targetMethod = class_getInstanceMethod(self, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    
    // 2.新增一个目标方法的别名方法
    NSString *aliasSelString = [NSString stringWithFormat:@"oc_dynamic_%@", NSStringFromSelector(selector)];
    const char *typeEncoding = method_getTypeEncoding(targetMethod);
    BOOL isSuccessed = class_addMethod(self, NSSelectorFromString(aliasSelString), targetMethodIMP, typeEncoding);
    NSLog(@"%@ add method successfully: %d", aliasSelString, isSuccessed);
    
    // 3.将目标方法实现替换成 _objc_msgForward
    class_replaceMethod(self, selector, (IMP)_objc_msgForward, typeEncoding);
    
    // 4.将目标类的 forwardInvocation 替换为自定义 dy_forwardInvocation_center
    class_replaceMethod(self, @selector(forwardInvocation:), (IMP)dy_forwardInvocation_center, "v@:@");
}

static NSMutableDictionary<NSString *, OCDynamicBlock>* dynamicBlockMap(void)
{
    static NSMutableDictionary *_dynamicBlockMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dynamicBlockMap = [NSMutableDictionary dictionary];
    });
    
    return _dynamicBlockMap;
}

static void dy_forwardInvocation_center(id self, SEL _cmd, NSInvocation *anInvocation)
{
    // 获取回调 block
    OCDynamicBlock targetBlock = [dynamicBlockMap() objectForKey:NSStringFromSelector(anInvocation.selector)];
    
    // 将 anInvocation 的 sel 设置为别名 sel
    NSString *aliasSelString = [NSString stringWithFormat:@"oc_dynamic_%@", NSStringFromSelector(anInvocation.selector)];
    anInvocation.selector = NSSelectorFromString(aliasSelString);
    
    // 调用回调 block
    targetBlock(self, anInvocation);
}

@end

```

下面是 MyClassC 的实现代码

```objc
@implementation MyClassC

- (void)sayHelloTo:(NSString *)name
{
    NSLog(@"%s: %@", __func__, name);
}

@end
```

下面是 MyClassC 的测试代码

```objc
- (void)hookMyClassCMethod
{
    [MyClassC dy_hookSelector:@selector(sayHelloTo:) withBlock:^(id  _Nonnull self, NSInvocation * _Nonnull originalInvocation) {
        __weak id value = nil;
        [originalInvocation getArgument:&value atIndex:2];
        NSLog(@"%@ %@", NSStringFromSelector(originalInvocation.selector), value);
    }];
    
    // 测试 MyClassC
    [[MyClassC new] sayHelloTo:@"jack"];
}
```

虽然调用了 `[[MyClassC new] sayHelloTo:@"jack"];`，但是你会发现并没有对应的`sayHelloTo: jack`日志输出，而是输出了：`oc_dynamic_sayHelloTo: jack`。这说明了该方法调用被成功拦截并且回调到了对应的 block 中。至此，我们简要的热修复功能已实现了。是不是很简单？

上面的示例代码都是本地 Hard Code，下面就来聊聊如何动态的 Hook 指定类的方法及改变修改目标方法的调用行为。从 MyClassC 的测试代码中可以看出，我们可以用字符串反射的方式实现动态 Hook。

```objc
[self dy_hookMethodWithHookMap:@{
     @"cls": @"MyClassC",
     @"sel": @"sayHelloTo:"
}];

// 测试 MyClassC
[[MyClassC new] sayHelloTo:@"jack"];

- (void)dy_hookMethodWithHookMap:(NSDictionary *)hookMap {
    Class cls = NSClassFromString([hookMap objectForKey:@"cls"]);
    SEL sel = NSSelectorFromString([hookMap objectForKey:@"sel"]);
    
    [cls dy_hookSelector:sel withBlock:^(id  _Nonnull self, NSInvocation * _Nonnull originalInvocation) {
        __weak id value = nil;
        [originalInvocation getArgument:&value atIndex:2];
        NSLog(@"%@ %@", NSStringFromSelector(originalInvocation.selector), value);
    }];
}
``` 

上面的示例代码中，我们只需要构建指定规则的 hookMap 即可实现动态 Hook，我们可以根据实际项目实现一套适合自己的 DSL 语法。然后解析对应的 DSL 生成 hookMap。

由于我们拿到了目标方法调用的 NSInvocation 对象，所以我们可以任意的修改方法的参数值、返回值、selector 及 target。下面简单介绍下如何实现上面的目标。

### 一、方法替换为空实现
替换为空实现其实很简单，就是不处理回调中的 `originalInvocation` 即可。

```objc
[weakSelf dy_hookMethodWithHookMap:@{
    @"cls": @"ViewController",
    @"sel": @"myEmptyMethod",
    @"isReplcedEmpty": @(YES)
}];

// 将不会打印 -[ViewController myEmptyMethod]
[weakSelf myEmptyMethod];

[cls dy_hookSelector:sel withBlock:^(id  _Nonnull self, NSInvocation * _Nonnull originalInvocation) {
	
   if ([hookMap[@"isReplcedEmpty"] boolValue]) {
        NSLog(@"[%@ %@] replace into empty IMP", cls, NSStringFromSelector(sel));
        return;
   }
}];
```

### 二、方法参数修改
通过 NSInvocation 的 `- (void)setArgument:(void *)argumentLocation atIndex:(NSInteger)idx`即可修改方法参数值。例如动态的把 `sayHelloTo:` 方法的参数值`jack` 改为 `Lili`。

**知识点：**

> 所有 OC 方法都有两个隐藏的参数：第一个是`self`, 第二个是`selector`，所以我们在设置参数值时 index 是从 2 开始的

```objc
[weakSelf dy_hookMethodWithHookMap:@{
     @"cls": @"MyClassC",
     @"sel": @"sayHelloTo:",
     @"parameters": @[@"Lili"]
}];
                                
// 打印信息是-[MyClassC sayHelloTo:]: Lili ，而不是 jack
[[MyClassC new] sayHelloTo:@"jack"];

[cls dy_hookSelector:sel withBlock:^(id  _Nonnull self, NSInvocation * _Nonnull originalInvocation) {
    
    if ([hookMap[@"isReplcedEmpty"] boolValue]) {
        NSLog(@"[%@ %@] replace into empty IMP", cls, NSStringFromSelector(sel));
        return;
    }
    
    [parameters enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [originalInvocation setArgument:&obj atIndex:idx + 2];
    }];
    
    [originalInvocation invoke];
}];
```

### 三、方法返回值修改
通过 NSInvocation 的 `- (void)setReturnValue:(void *)retLoc`即可修改方法返回值。例如将 `MyClassC` 的 `className` 方法的返回值改为 `Return value had change`

```objc
- (NSString *)className {
    return @"MyClassC";
}

[weakSelf dy_hookMethodWithHookMap:@{
     @"cls": @"MyClassC",
     @"sel": @"className",
     @"returnValue": @"Return value had change"
}];
                                
// 打印信息是 Return value had change ，而不是 MyClassC
[NSLog(@"%@", [[MyClassC new] className]);

[cls dy_hookSelector:sel withBlock:^(id  _Nonnull self, NSInvocation * _Nonnull originalInvocation) {
	 if ([hookMap[@"isReplcedEmpty"] boolValue]) {
        NSLog(@"[%@ %@] replace into empty IMP", cls, NSStringFromSelector(sel));
        return;
    }

    [parameters enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [originalInvocation setArgument:&obj atIndex:idx + 2];
    }];
    
    [originalInvocation invoke];
    
    id returnValue = [hookMap objectForKey:@"returnValue"];
    if (returnValue) {
		[originalInvocation setReturnValue:&returnValue];
    }
}];
```

### 四、方法调用前后插入自定义代码
我们可以在回调 block 中做一些自定义调用，等这些完成后再调用`[originalInvocation invoke]` 。例如在 `myMethod ` 调用前调用 `dynamicCallMethod `方法

```objc
- (void)dynamicCallMethod {
    NSLog(@"%s Dynamic call", __func__);
}

[weakSelf dy_hookMethodWithHookMap:@{
    @"cls": @"MyClassC",
    @"sel": @"myMethod",
    @"customMethods": @[@"self.dynamicCallMethod"]
 }];
                                
// 会先打印 -[MyClassC dynamicCallMethod] Dynamic call，然后再打印 -[MyClassC myMethod]
[[MyClassC new] myMethod];

[cls dy_hookSelector:sel withBlock:^(id  _Nonnull self, NSInvocation * _Nonnull originalInvocation) {
    
    if ([hookMap[@"isReplcedEmpty"] boolValue]) {
        NSLog(@"[%@ %@] replace into empty IMP", cls, NSStringFromSelector(sel));
        return;
    }
    
    [customMethods enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray<NSString *> *targets = [obj componentsSeparatedByString:@"."];
        
        id target = nil;
        if ([targets.firstObject isEqualToString:@"self"]) {
            target = self;
        }
        
        SEL sel = NSSelectorFromString(targets.lastObject);
        NSMethodSignature *targetSig = [[target class] instanceMethodSignatureForSelector:sel];
        
        NSInvocation *customInvocation = [NSInvocation invocationWithMethodSignature:targetSig];
        customInvocation.target = target;
        customInvocation.selector = sel;
        [customInvocation invoke];
        
        target = nil;
    }];
    
    [parameters enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [originalInvocation setArgument:&obj atIndex:idx + 2];
    }];
    
    [originalInvocation invoke];
    
    id returnValue = [hookMap objectForKey:@"returnValue"];
    if (returnValue) {
		[originalInvocation setReturnValue:&returnValue];
    }
}];

```

上面简单的阐述了如何通过字符串方式调用 OC 方法，如果要实现可以调用任意 OC 方法，还需要继续完善上面的解析逻辑，但其中核心点都是通过构建 `NSInvocation`。这里算是抛砖引玉吧。

OCDynamic 只是简单的实现了热修复的核心逻辑，这是远远不够的。虽然我们可以不断完善，但是业界已经有了完善的开源库：[Aspects](https://github.com/steipete/Aspects)。`Aspects`库是`OCDynamic`的加强完善版。因此，我们只需要站在巨人的肩膀上即可，就没有必要重复造轮子了。下面就来分析下`Aspects`的基本原理及其可以优化的点。

## [Aspects](https://github.com/steipete/Aspects) 
Aspects 可以拦截目标方法调用，并且将目标方法调用以 NSInvocation 形式返回。 下面简单介绍下其主要构成、Hook 流程、Invoke 流程及该库存在的一些问题。

* **AspectsContainer**：Tracks all aspects for an object/class
* **AspectIdentifier**：Tracks a single aspect

### 一、Hook 流程
1. 检查 selector 是否可以替换，里面涉及一些黑名单等判断
2. 获取 AspectsContainer，如果为空则创建并绑定目标类
3. 创建 AspectIdentifier，用来保存回调`block`和 `AspectOptions` 等信息
4. 将目标类 `forwardInvocation:` 方法替换为自定义方法（\_\_ASPECTS\_ARE\_BEING\_CALLED\_\_）
5. 目标类新增一个带有` aspects_`前缀的方法，新方法（aliasSelector）实现跟目标方法相同
6. 将目标方法实现替换为 `_objc_msgForward`

```objc
// 将目标类 forwardInvocation: 方法替换为自定义方法
IMP originalImplementation = class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
if (originalImplementation) {
    class_addMethod(klass, NSSelectorFromString(AspectsForwardInvocationSelectorName), originalImplementation, "v@:@");
}

// 目标类新增一个带有 aspects_ 前缀的方法，新方法（aliasSelector）实现跟目标方法相同
Method targetMethod = class_getInstanceMethod(klass, selector);
IMP targetMethodIMP = method_getImplementation(targetMethod);

const char *typeEncoding = method_getTypeEncoding(targetMethod);
SEL aliasSelector = NSSelectorFromString([AspectsMessagePrefix stringByAppendingFormat:@"_%@", NSStringFromSelector(selector)]);
class_addMethod(klass, aliasSelector, method_getImplementation(targetMethod), typeEncoding);

// 将目标方法实现替换为 _objc_msgForward
class_replaceMethod(klass, selector, aspect_getMsgForwardIMP(self, selector), typeEncoding);

```

#### 二、Invoke 流程
1. 调用目标方法进入消息转发流程
2. 调用自定义 `__ASPECTS_ARE_BEING_CALLED__` 方法
3. 获取对应 invocation，将 invocation.selector 设置为 aliasSelector
4. 通过 aliasSelector 获取对应 AspectsContainer
5. 根据 AspectOptions 调用用户自定实现（目标方法调用前/后/替换）

#### 三、Aspects 优化
* 使用了自旋锁，存在优先级反转问题，使用 `pthread_mutex_lock` 代替即可
* 特殊 `struct` 判断逻辑不够全面，例如 NSRange, NSPoint 等在 x86-64 位架构下有问题，需要自行兼容

```objc
#if defined(__LP64__) && __LP64__
    if (valueSize == 16) {
        methodReturnsStructValue = NO;
    }
#endif
```

* 类方法无法直接 hook, 不过可以 hook 其 `Meta class` 元类方式进行解决
	
```c
object_getClass(targetCls)
```

* 无法同时 hook 一个类的实例方法和类方法，原因是使用了相同的 `swizzledClasse` key, 解决如下：

```objc
static Class aspect_swizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = [NSString stringWithFormat:@"%@_%p", NSStringFromClass(klass), klass];

    _aspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if (![swizzledClasses containsObject:className]) {
            aspect_swizzleForwardInvocation(klass);
            [swizzledClasses addObject:className];
        }
    });
    return klass;
}

static void aspect_undoSwizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = [NSString stringWithFormat:@"%@_%p", NSStringFromClass(klass), klass];

    _aspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if ([swizzledClasses containsObject:className]) {
            aspect_undoSwizzleForwardInvocation(klass);
            [swizzledClasses removeObject:className];
        }
    });
}
```

## NSInvocation 的坑
NSInvocation 在取其参数值和返回值的时候需要注意内存管理的问题，下面介绍下在实际开发中所遇到的问题。

### 一、`EXC_BAD_ACCESS`

从 `-forwardInvocation:` 里的 `NSInvocation` 对象取参数值时，若参数值是id类型，一般会这样取：

```objc
id value = nil;
[invocation getArgument:&value atIndex:2];
```

但是这种写法存在 `EXC_BAD_ACCESS` 风险。例如：Hook NSMutableArray 的 insertObject:atIndex: 方法。你会发现在有些系统调用会出现野指针崩溃

```objc
[NSClassFromString(@"__NSArrayM") aspect_hookSelector:@selector(insertObject:atIndex:) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info){
    
    id value = nil;
    [info.originalInvocation getArgument:&value atIndex:2];
    if (value) {
        [info.originalInvocation invoke];
    }
} error:NULL];
```

开启 `Zombie objects` 下的异常打印

``` objc
-[UITraitCollection retain]: message sent to deallocated instance 0x6000007cde00    
```

**原因分析：**

1. NSInvocation 不会引用参数，详情可以看官方文档（This class does not retain the arguments for the contained invocation by default）
2. ARC 在隐式赋值不会自动插入 retain 语句。在`[info.originalInvocation getArgument:&value atIndex:2];` 中，因为 value 是通过指针赋值（隐式赋值），所以 ARC 机制并不生效（具体可以参考：[ARC - Retainable object pointers section](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#retainable-object-pointers)），这也导致了 value 没有调用 `retain` 方法
3. ARC 下 `id value` 相当于 `__strong id vaule`，`__strong` 类型的变量会在当前作用域结束后自动调用 `release`方法进行释放。其实现如下所示：

```objc
void objc_storeStrong(id *object, id value) {
	id oldValue = *object;
	value = [value retain];
	*object = value;
	[oldValue release];
}
```

综上所述可以得出：value 并没有持有参数对象但又对参数对象进行释放，这导致参数对象被提前释放。如果此时再对该对象发送消息则会发生野指针崩溃

**解决办法：**

1、将 value 变成  `__unsafe_unretained` 或 `__weak`，让 ARC 在它退出作用域时不插入 release 语句

```objc
__unsafe_unretained id value = nil;
```

2、通过 `__bridge` 转换让 value 持有返回对象，显示赋值

```objc
id value = nil;
void *result;
[invocation getArgument:&result atIndex:2];
value = (__bridge id)result;
```

### 二、Memory Leak

使用 `NSInvocation` 调用`alloc/new/copy/mutableCopy`方法时会发生内存泄漏，示例如下：

```objc
- (void)memoryLeakA
{
    NSMethodSignature *signature = [NSObject methodSignatureForSelector:@selector(new)];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = MyClassA.class;
    invocation.selector = @selector(new);
    [invocation invoke];
}

- (void)memoryLeakB
{
    [MyClassB performSelector:@selector(new)];
}

```

使用 **Memory Graph** 查看对象内存时会发现 `MyClassA` 和 `MyClassB` 都被标记为内存泄漏了

**原因分析：**

ARC 机制中，当调用 `alloc/new/copy/mutableCopy` 方法返回的对象是直接持有的，其引用计数为`1`。在常规的方法调用时编译器会自动调用 release，而使用`NSInvocation`或`performSelector:`动态调用`alloc/new/copy/mutableCopy`方法时，ARC 并不会自动调用`release`，所以导致内存泄漏。

**谨记：**

> ARC 对动态方法调用是无能为力的😅 

**温馨提示：**
> 有兴趣的可以 Xcode 看看这两种方式的汇编实现🤔 （Product -> Perform Action -> Assemble）

**解决办法：** 

1. 使用`__bridge_transfer`修饰符将返回对象的内存管理权移交出来，让外部对象管理其内存

```objc
// 方法1 
id resultObj = nil;
NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
invocation.target = [NSObject class];
invocation.selector = @selector(new);
[invocation invoke];

void *result;
[invocation getReturnValue:&result];

if ([selName isEqualToString:@"alloc"] ||
    [selName isEqualToString:@"new"] ||
    [selName isEqualToString:@"copy"] ||
    [selName isEqualToString:@"mutableCopy"]) {
    resultObj = (__bridge_transfer id)result;
} else {
    resultObj = (__bridge id)result;
}

```

2. 采用常规方法调用代替 NSInvocation

```objc
// 方法2
id resultObj = nil;
if ([selName isEqualToString:@"alloc"]) {
    resultObj = [[target class] alloc];
} else if ([selName isEqualToString:@"new"]) {
    resultObj = [[target class] new];
} else if ([selName isEqualToString:@"copy"]) {
    resultObj = [target copy];
} else if ([selName isEqualToString:@"mutableCopy"]) {
    resultObj = [target mutableCopy];
} else {
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = [NSObject class];
    invocation.selector = @selector(new);
    [invocation invoke];

    void *result;
    [invocation getReturnValue:&result];
    resultObj = (__bridge id)result;
}
```

## 审核分析
其实能不能成功上线是热修复的首要前提，我们辛辛苦苦开的框架如果上不了线，那一切都是徒劳无功。下面就来分析下其审核风险。

- 首先这个是我们自研的，所以苹果审核无法通过静态代码扫描识别。
- 其次系统库内部也大量使用了消息转发机制。可以通过符号断点验证`_objc_msgForward`和`forwardInvocation:`。所以不存在风险。
- 苹果无法采用动态检验消息转发，非系统调用都不能使用，这个成本太大了，几乎不可能。
- Aspects 库目前线上有大量使用，为此不用担心。就算 Aspects 被禁用，参考 Aspects 自己实现也不难。

综上所述：无审核风险。

当然热修复框架只是为了更好的控制线上 bug 影响范围和给用户更好的体验。不建议基于其它目的使用🤔

## 后记
随着项目的业务复杂度增加，线上问题可能存在一些 C 函数的动态调用和 block 参数的修改，这边介绍一个强大的库，外部函数接口：[libffi](https://github.com/libffi/libffi)，它也可以拦截函数和获取函数调用参数。相比 Aspects，其功能更加强大，不但可以动态调用 C 函数，而且还可以用 libffi 实现一套基于 IMP 替换（拥有更好的性能）的热修复框架。有兴趣的童鞋请参考：[libffi doc](https://sourceware.org/libffi/) 和 [如何动态调用 C 函数](http://blog.cnbang.net/tech/3219/) 

取名深入只是为了引人注目，实则只是个人的一点心得。由于水平有限，如有不对之处，欢迎大家批评指正。

**如果觉得文章不错的话，欢迎🌟以资鼓励😄**

**温馨提示：**

> 阅读文章的时候建议搭配示例 HotFixDemo，这样理解会更加深刻。


## 参考文献
1. [Objective-C Runtime Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Introduction/Introduction.html)
2. [NSInvocation returns value but makes app crash with EXC\_BAD\_ACCESS](https://stackoverflow.com/questions/22018272/nsinvocation-returns-value-but-makes-app-crash-with-exc-bad-access/22034059#22034059)
3. [JSPatch 实现原理详解](https://github.com/bang590/JSPatch/wiki/JSPatch-%E5%AE%9E%E7%8E%B0%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3)
4. [objc\_msgSend\_stret](http://sealiesoftware.com/blog/archive/2008/10/30/objc_explain_objc_msgSend_stret.html)
5. [objc_msgSend() Tour Part 1: The Road Map](http://www.friday.com/bbum/2009/12/18/objc_msgsend-part-1-the-road-map/)
6. [-rac_signalForSelector: may fail for struct returns](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/783)
7. [Objective-C Automatic Reference Counting (ARC)](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-retainautorelease)
8. [Aspects](https://github.com/steipete/Aspects)
