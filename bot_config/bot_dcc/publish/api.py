class PublishError(Exception):
    pass

class Step:
    label = "Step"
    order = 50
    def process(self, context):
        raise NotImplementedError

class Collector(Step):
    label = "Collector"

class Validator(Step):
    label = "Validator"

class Extractor(Step):
    label = "Extractor"

class Integrator(Step):
    label = "Integrator"
