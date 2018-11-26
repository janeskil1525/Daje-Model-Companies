package Daje::Model::Companies;

use Mojo::Base -base;
our $VERSION = '0.1';

use Try::Tiny;

has 'pg';

sub init{
	my $self = shift;
	
	my $result = try{
		$self->pg->migrations->name('companies')->from_data('Daje::Model::Companies', 'companies.sql')->migrate(0);
		return $self;
	}catch{
		say $_;
		return ;
	};
}

sub save_company{
    my($self, $data, $token) = @_;
    
    
    eval{
        my $tx = $self->pg->db->begin();
       #
       
        my $company_pkey = $self->pg->db->query(
                    "INSERT INTO companies
                        (company, name, registrationnumber, homepage, phone, menu_group)
                    VALUES (?,?,?,?,?,?)
                    ON CONFLICT (company)
                        DO UPDATE
                    SET name = ?,
                        registrationnumber = ?,
                        homepage = ?,
                        phone = ?,
                        menu_group = ?
                        RETURNING companies_pkey",(
                            $data->{company}, $data->{name}, $data->{registrationnumber},
                            $data->{homepage}, $data->{phone}, $data->{menu_group},
                            $data->{name}, $data->{registrationnumber},
                            $data->{homepage}, $data->{phone}, $data->{menu_group},
                        ))->hash->{companies_pkey};
     	
        my $addresses_pkey =$self->pg->db->query(
                "INSERT INTO addresses
                    (name, address1,city, zipcode, country)
                VALUES(?,?,?,?,?)
                    ON CONFLICT (name)
                DO UPDATE SET address1 = ?, city = ?, zipcode = ?, country = ?
                    RETURNING addresses_pkey",
                    (
                            $data->{name},
                            $data->{address1},
                            $data->{city},
                            $data->{zipcode},
                            $data->{country},
                            $data->{address1},
                            $data->{city},
                            $data->{zipcode},
                            $data->{country},
                 ))->hash->{addresses_pkey};
        
        $self->pg->db->query(
                "INSERT INTO addresses_company
                    (companies_fkey, addresses_fkey)
				VALUES (?,?)
                    ON CONFLICT (companies_fkey, addresses_fkey) 
				DO NOTHING ",
                    ($company_pkey,
                     $addresses_pkey));
        
        say "in save_company connected_companies " . $data->{connected_companies};
        if($data->{connected_companies} == 1){
            $self->pg->db->query(
                "INSERT INTO companies_companies
                    (parent_companies_fkey, child_companies_fkey)
				VALUES ((select get_company_fkey(?)),?)
                    ON CONFLICT (parent_companies_fkey, child_companies_fkey) 
				DO NOTHING ",
                    ($token, $company_pkey));
       }
       $tx->commit();
    };
    
    return $@ if $@;
    return 1;
}

sub load_loggedincompany_p{
    my ($self, $token) = @_;
    
    my $stmt = qq{SELECT a.companies_pkey, a.company, a.name, c.address1, c.address2, c.zipcode, c.city, c.country, a.menu_group
        FROM companies as a
            JOIN addresses_company as b
                ON a.companies_pkey = b.companies_fkey
            JOIN addresses as c
                ON c.addresses_pkey = b.addresses_fkey
        WHERE companies_pkey = (select get_company_fkey(?))};

    my $result = $self->pg->db->query_p($stmt, $token);
    
    return $result;
    
}

sub load_company_p{
     my ($self, $companies_pkey) = @_;
     
     my $stmt = qq{SELECT a.companies_pkey, a.company, a.name, c.address1, c.address2, c.zipcode, c.city, c.country, a.menu_group
        FROM companies as a
            JOIN addresses_company as b
                ON a.companies_pkey = b.companies_fkey
            JOIN addresses as c
                ON c.addresses_pkey = b.addresses_fkey
        WHERE companies_pkey = ?};
                      
    my $result = $self->pg->db->query_p($stmt, ($companies_pkey));
    
    return $result;
}

sub list_companies_from_type_p{
    my ($self, $company_type)  = @_;
    
    my $stmt = qq{SELECT
                    a.companies_pkey, a.company, a.name, c.address1,
                    c.address2, c.zipcode, c.city, c.country
                FROM companies as a
                    JOIN addresses_company as b
                        ON a.companies_pkey = b.companies_fkey
                    AND a.menu_group = ?
                    JOIN addresses as c
                        ON c.addresses_pkey = b.addresses_fkey
                order by name DESC  };   
                         
    my $result = $self->pg->db->query_p($stmt, ($company_type));
    
    return $result;
}

sub list_connected_companies_p{
    my ($self, $token)  = @_;
    
    my $stmt = qq{SELECT
                    a.companies_pkey, a.company, a.name, c.address1,
                    c.address2, c.zipcode, c.city, c.country
                FROM companies as a
                    JOIN addresses_company as b
                        ON a.companies_pkey = b.companies_fkey
                    JOIN addresses as c
                        ON c.addresses_pkey = b.addresses_fkey
                    JOIN companies_companies as d
                        ON child_companies_fkey = a.companies_pkey
                    AND parent_companies_fkey = (select get_company_fkey(?))
                    UNION
                SELECT
                    a.companies_pkey, a.company, a.name, c.address1,
                    c.address2, c.zipcode, c.city, c.country
                FROM companies as a
                    JOIN addresses_company as b
                        ON a.companies_pkey = b.companies_fkey
                    AND a.companies_pkey = (select get_company_fkey(?))
                    JOIN addresses as c
                        ON c.addresses_pkey = b.addresses_fkey
                order by name DESC  };
                
    my $result = $self->pg->db->query_p($stmt, ($token, $token));
    
    return $result;
}

sub list_all_p{
    my ($self, $companytype)  = @_;
    
    my $stmt = qq{SELECT
                    a.companies_pkey, a.company, a.name, c.address1,
                    c.address2, c.zipcode, c.city, c.country
                FROM companies as a
                    JOIN addresses_company as b
                        ON a.companies_pkey = b.companies_fkey
                            AND menu_group = ?
                    JOIN addresses as c
                        ON c.addresses_pkey = b.addresses_fkey
                order by name DESC  };   

    my $result = $self->pg->db->query_p($stmt, $companytype);
    
    return $result;
}

sub create_user_link_p{
    my ($self, $users_fkey, $companies_fkey) = @_;
    
    my $stmt = "INSERT INTO users_companies (users_fkey, companies_fkey)
				VALUES (?,?)
					ON CONFLICT (companies_fkey, users_fkey)
				DO NOTHING";
     say  $stmt;
     say "users_fkey '$users_fkey'";
     say "companies_fkey '$companies_fkey'";
     return $self->pg->db->query_p($stmt,($users_fkey, $companies_fkey));
}


1;

__DATA__

@@ companies.sql

-- 1 up


-- 1 down