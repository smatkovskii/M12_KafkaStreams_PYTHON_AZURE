import logging

import faust
from dateutil.parser import parse as parse_date
from dateutil.relativedelta import relativedelta
from faust import StreamT
from faust.serializers import codecs
from schema_registry.client import SchemaRegistryClient
from schema_registry.serializers.faust import FaustSerializer

logger = logging.getLogger(__name__)

def registerSourceSerializer():
    schemaClient = SchemaRegistryClient(url="http://schemaregistry.confluent.svc.cluster.local:8081")
    schemaName = 'expedia-value'
    schemaVersion = schemaClient.get_schema(schemaName)
    if schemaVersion is None:
        logger.error(f'Schema client was unable to get "{schemaName}" from the registry')
        raise ValueError(f'Schema "{schemaName}" not found')
    codecs.register('expedia_avro_codec', FaustSerializer(schemaClient, schemaName, schemaVersion.schema))

registerSourceSerializer()

class ExpediaRecord(faust.Record, serializer='expedia_avro_codec'):
    id: int
    date_time: str
    site_name: int
    posa_container: int
    user_location_country: int
    user_location_region: int
    user_location_city: int
    orig_destination_distance: float
    user_id: int
    is_mobile: int
    is_package: int
    channel: int
    srch_ci: str
    srch_co: str
    srch_adults_cnt: int
    srch_children_cnt: int
    srch_rm_cnt: int
    srch_destination_id: int
    srch_destination_type_id: int
    hotel_id: int

class ExpediaExtRecord(ExpediaRecord, serializer='json'):
    stay_category: str


app = faust.App('kafkastreams', broker='kafka://kafka:9092') # TODO restore app name
source_topic = app.topic('expedia', partitions=3, value_type=ExpediaRecord)
destination_topic = app.topic('expedia-ext', key_type=str, value_type=ExpediaExtRecord) # TODO restore topic name


@app.agent(source_topic)
async def handle(stream: StreamT[ExpediaRecord]):
    async for message in stream:
        if message is None:
            logger.info('No messages')
            continue

        checkinDate = parse_date(message.srch_ci) if message.srch_ci else None
        checkoutDate = parse_date(message.srch_co) if message.srch_co else None
        stayCategory = ''
        if checkinDate is None or checkoutDate is None or relativedelta(checkoutDate, checkinDate).days < 1:
            stayCategory = 'Erroneous data'
        else:
            daysDiff = relativedelta(checkoutDate, checkinDate).days
            if 1 <= daysDiff <= 4:
                stayCategory = 'Short stay'
            elif 5 <= daysDiff <= 10:
                stayCategory = 'Standard stay'
            elif 11 <= daysDiff <= 14:
                stayCategory = 'Standard extended stay'
            else:
                stayCategory = 'Long stay'

        await destination_topic.send(key=str(message.id), value=ExpediaExtRecord(**message.asdict(), stay_category=stayCategory))

if __name__ == '__main__':
    app.main()
