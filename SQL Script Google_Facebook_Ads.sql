SELECT * FROM google_ads_basic_daily;
SELECT * FROM "facebook_ads_basic_daily";

--1.Спочатку пропишемо код, який скомпонує таблиці по Google та по Facebook, через CTE та Union All
WITH combined_ads AS  (
SELECT ad_date,
url_parameters,
spend,
impressions,
reach,
clicks,
leads, 
value
FROM google_ads_basic_daily
UNION ALL  
SELECT ad_date,
url_parameters,
spend,
impressions,
reach,
clicks,
leads, 
value
FROM facebook_ads_basic_daily
)
SELECT ad_date,
CASE
  WHEN lower(substring(url_parameters FROM '[?&]utm_campaign=([^&#]+)')) IS NULL THEN '0'
  ELSE lower(substring(url_parameters FROM '[?&]utm_campaign=([^&#]+)'))
END AS utm_campaign,
url_parameters,
spend,
impressions,
reach,
clicks,
leads, 
value
FROM combined_ads;

--2. Далі з даної CTE обираємо необхідні параметри та рахуємо метрики з усуненням помилки ділення на 0
WITH combined_ads AS  (
SELECT ad_date,
url_parameters,
spend,
impressions,
clicks,
value
FROM google_ads_basic_daily
UNION ALL 
SELECT ad_date,
url_parameters,
spend,
impressions,
clicks,
value
FROM facebook_ads_basic_daily
)
SELECT ad_date,
CASE
    WHEN lower(substring(url_parameters FROM '[?&]utm_campaign=([^&#]+)')) = 'nan' THEN NULL
    ELSE lower(substring(url_parameters FROM '[?&]utm_campaign=([^&#]+)'))
  END AS utm_campaign,
SUM(spend) AS total_spend,
SUM(impressions) AS total_impressions,
SUM(clicks) AS total_clicks, 
SUM(value) AS total_value,
		CASE 
		  WHEN SUM(impressions) > 0 THEN ROUND(SUM(clicks)::numeric / SUM(impressions), 3)
		  ELSE NULL
		END AS CTR_PERCENT,
		CASE 
		  WHEN SUM(clicks) > 0 THEN ROUND(SUM(spend)::numeric / SUM(clicks), 3)
		  ELSE NULL
		END AS CPC_DOLLARS,
		CASE 
			WHEN SUM(impressions) > 0 THEN ROUND(SUM(clicks)::numeric / SUM(impressions)*1000, 3)
		  ELSE NULL
		END AS CPM_DOLLARS,
		CASE 
			WHEN sum (spend) > 0 THEN round (sum(value)::NUMERIC/sum(spend)-1, 3)
		END AS ROMI_PERCENT
FROM combined_ads
GROUP BY ad_date, utm_campaign
ORDER BY ad_date;




--*Додаткове завдання
DROP FUNCTION IF EXISTS decode_utm_campaign(TEXT);
DROP FUNCTION IF EXISTS decode_utm_campaign(INTEGER);
DROP FUNCTION IF EXISTS decode_utm_campaign(VARCHAR); -- спочатку функція працювала, а запит - ні, тому вирішила подивитися, чи є в БД інші функції з такою ; назвою, і намагалася їх видалити

--Далі створюємо функцію, яка допомагає розкодувати посилання, але назвемо її decode_utm_campaign_2, щоб не було суперечностей
CREATE OR REPLACE FUNCTION decode_utm_campaign_2(url_parameters TEXT)
RETURNS TEXT AS $$
DECLARE
  campaign_value TEXT;
BEGIN
  campaign_value := substring(url_parameters FROM '[\?&]utm_campaign=([^&#]+)');

  IF campaign_value IS NULL OR trim(lower(campaign_value)) = 'nan' THEN
    RETURN NULL;
  ELSE
    RETURN campaign_value;
  END IF;
END;
$$ LANGUAGE plpgsql;

--Тепер виконуємо запит, щоб розпарсити посилання, тобто дістати конкретну частину - utm_campaign, і приєднуємо цю частину до таблиці combined_ads
WITH combined_ads AS  (
SELECT ad_date,
url_parameters,
spend,
impressions,
clicks,
"value"
FROM google_ads_basic_daily
UNION ALL 
SELECT ad_date,
url_parameters,
spend,
impressions,
clicks,
"value"
FROM facebook_ads_basic_daily
),
decoded_ads AS (
  SELECT *,
         decode_utm_campaign_2(url_parameters) AS utm_campaign
  FROM combined_ads
)
SELECT ad_date,
utm_campaign,
SUM(spend) AS total_spend,
SUM(impressions) AS total_impressions,
SUM(clicks) AS total_clicks, 
SUM("value") AS total_value,
		CASE 
		  WHEN SUM(impressions) > 0 THEN ROUND(SUM(clicks)::numeric / SUM(impressions), 3)
		  ELSE NULL
		END AS CTR,
		CASE 
		  WHEN SUM(clicks) > 0 THEN ROUND(SUM(spend)::numeric / SUM(clicks), 3)
		  ELSE NULL
		END AS CPC,
		CASE 
			WHEN SUM(impressions) > 0 THEN ROUND(SUM(spend)::numeric / SUM(impressions), 3)
		  ELSE NULL
		END AS CPM,
		CASE 
			WHEN SUM(spend) > 0 THEN ROUND(SUM("value")::numeric/SUM(spend)-1, 3)
		END AS ROMI
FROM decoded_ads
GROUP BY ad_date, utm_campaign
ORDER BY ad_date;



