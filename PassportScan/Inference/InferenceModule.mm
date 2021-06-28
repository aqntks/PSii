
#import "InferenceModule.h"
#import <LibTorch/LibTorch.h>


// 학습 한 모델의 input 사이즈 기입
const int input_width = 640;
const int input_height = 640;
const int output_size = 25200*43; // 학습 한 모델의 output 크기 Row * Column = Row * (Class 수 + 5) = 25200 * 43

@implementation InferenceModule {
    torch::jit::script::Module _impl;
}

// 모델 로드
- (nullable instancetype)initWithFileAtPath:(NSString*)filePath {
    self = [super init];
    if (self) {
        try {
            _impl = torch::jit::load(filePath.UTF8String);
            _impl.eval();
        } catch (const std::exception& exception) {
            NSLog(@"%s", exception.what());
            return nil;
        }
    }
    return self;
}

// Object Detection 진행
- (NSArray<NSNumber*>*)detectImage:(void*)imageBuffer {
    try {
        at::Tensor tensor = torch::from_blob(imageBuffer, { 1, 3, input_width, input_height }, at::kFloat);
        torch::autograd::AutoGradMode guard(false);
        at::AutoNonVariableTypeMode non_var_type_mode(true);

        auto outputTuple = _impl.forward({ tensor }).toTuple();
        auto outputTensor = outputTuple->elements()[0].toTensor();

        float* floatBuffer = outputTensor.data_ptr<float>();

        if (!floatBuffer) {
            return nil;
        }
        NSMutableArray* results = [[NSMutableArray alloc] init];
        for (int i = 0; i < output_size; i++) {
          [results addObject:@(floatBuffer[i])];
        }

        return [results copy];

    } catch (const std::exception& exception) {
        NSLog(@"%s", exception.what());
    }

    return nil;
}

//- (void)dealloc {
//    [super dealloc];
//}

@end
