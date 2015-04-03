SELECT * FROM( 
  SELECT
    s.clientID client_id,
    (SUM(p.val) - SUM(s.saleTotal)) balance,

    CASE
      -- band_name_value could be NULL or ""
      WHEN (CHAR_LENGTH(band.field_band_name_value) > 0) THEN band.field_band_name_value
      -- some first/last have a trailing/leading space
      -- e.g. Wilson  Pickett
      ELSE CONCAT_WS(' ', first.field_first_name_value, last.field_last_name_value)
    END AS name,
    IFNULL(statement.sent, 'N/A') sent

  FROM sale s
  
  -- inner will produce same results due to line 20
  LEFT JOIN (SELECT
    s.saleID sale_id,
    -- sale payments should be 0 not NULL
    IFNULL(SUM(p.paymentAmount), 0) val
    FROM sale s
    -- ensure sales are included regardless if no associated payments
    LEFT JOIN payment p
    ON s.saleID = p.saleID
    GROUP BY sale_id) AS p
  ON s.saleID = p.sale_id

  INNER JOIN profile
  ON s.clientID = profile.uid

  -- following field_data tables may not have associated rows
  LEFT JOIN field_data_field_band_name band
  ON profile.pid = band.entity_id

  LEFT JOIN field_data_field_first_name first
  ON profile.pid = first.entity_id

  LEFT JOIN field_data_field_last_name last
  ON profile.pid = last.entity_id

  INNER JOIN users_roles r
  ON profile.uid = r.uid

  LEFT JOIN invoice i
  ON i.saleID = s.saleID

  -- table has multiple rows per client
  -- most recent statement date if one sent
  LEFT JOIN(SELECT
    s.customerID id,
    MAX(s.sentDate) sent
    FROM statementHistory s
    GROUP BY id
  ) AS statement
  ON s.clientID = statement.id

  -- LOGIC
  WHERE s.saleStatus != 'Void'
  AND s.type = 'Invoice'
  AND i.dueDate < CURDATE()
  -- clients only
  AND r.rid = 4
  -- Ignore anonymous
  AND profile.uid != 0

  GROUP BY client_id
  ORDER BY balance
) AS client

WHERE client.balance < 0
LIMIT 10
